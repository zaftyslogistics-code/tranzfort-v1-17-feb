import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import 'city_search_service.dart';

/// Google Places API (New) - Autocomplete + Place Details service.
///
/// Uses the new Places API endpoints which require the Places API (New) to be enabled
/// in Google Cloud Console. The new API uses different endpoints and field masks.
///
/// Cost optimization:
/// - Session tokens still work for Autocomplete
/// - Field masks reduce data transfer and cost for Place Details
class GooglePlacesService {
  // New Places API (v1) endpoints
  static const _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const _placesBaseUrl = 'https://places.googleapis.com/v1/places';

  final http.Client _client;

  GooglePlacesService({http.Client? client})
      : _client = client ?? http.Client();

  String get _apiKey => SupabaseConfig.googlePlacesApiKey;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': _apiKey,
  };

  /// Whether the service is configured with a valid API key.
  bool get isAvailable {
    final available = _apiKey.isNotEmpty;
    if (kDebugMode) {
      print('[GooglePlaces] Service available: $available (key: ${_apiKey.length} chars)');
    }
    return available;
  }

  /// Search for places using Google Places API (New) Autocomplete.
  ///
  /// [query] — user's typed text (min 3 chars recommended)
  /// [sessionToken] — UUID string, reuse across keystrokes in one session
  ///
  /// Returns a list of [PlacePrediction] with placeId and description.
  Future<List<PlacePrediction>> searchPlaces(
    String query, {
    required String sessionToken,
  }) async {
    if (kDebugMode) {
      print('[GooglePlaces] searchPlaces called: query="$query", session=$sessionToken');
    }
    
    if (!isAvailable) {
      if (kDebugMode) print('[GooglePlaces] ❌ Service not available - skipping API call');
      return [];
    }
    
    if (query.trim().length < 3) {
      if (kDebugMode) print('[GooglePlaces] Query too short (${query.length} chars) - skipping');
      return [];
    }

    try {
      final body = json.encode({
        'input': query,
        'sessionToken': sessionToken,
        'includedPrimaryTypes': ['geocode', 'establishment'],
        'includedRegionCodes': ['in'], // India only
      });

      if (kDebugMode) {
        print('[GooglePlaces] 🌐 Calling NEW Autocomplete API');
      }
      
      final response = await _client.post(
        Uri.parse(_autocompleteUrl),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        print('[GooglePlaces] Response status: ${response.statusCode}');
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('[GooglePlaces] ❌ API error: ${response.statusCode} - ${response.body}');
        }
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>? ?? [];
      
      if (kDebugMode) {
        print('[GooglePlaces] ✅ Got ${suggestions.length} suggestions');
      }

      return suggestions.map((s) {
        final placePrediction = s['placePrediction'] as Map<String, dynamic>?;
        if (placePrediction == null) return null;
        
        final placeId = placePrediction['placeId'] as String? ?? '';
        final text = placePrediction['text'] as Map<String, dynamic>?;
        final structuredFormat = text?['structuredFormat'] as Map<String, dynamic>?;
        
        return PlacePrediction(
          placeId: placeId,
          description: text?['text'] as String? ?? '',
          mainText: structuredFormat?['mainText']?['text'] as String? ?? '',
          secondaryText: structuredFormat?['secondaryText']?['text'] as String? ?? '',
        );
      }).whereType<PlacePrediction>().toList();
      
    } catch (e) {
      if (kDebugMode) {
        print('[GooglePlaces] ❌ Exception: $e');
      }
      return [];
    }
  }

  /// Get place details using Google Places API (New).
  ///
  /// This call ends the session token — Google bills the session here.
  /// Returns a [LocationResult] with precise coordinates and address.
  Future<LocationResult?> getPlaceDetails(
    String placeId, {
    required String sessionToken,
  }) async {
    if (kDebugMode) {
      print('[GooglePlaces] getPlaceDetails: placeId=$placeId, session=$sessionToken');
    }
    
    if (!isAvailable) {
      if (kDebugMode) print('[GooglePlaces] ❌ Service not available');
      return null;
    }

    try {
      // New API uses field masks to specify which fields to return
      final headers = {
        ..._headers,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,addressComponents',
      };
      
      final url = Uri.parse('$_placesBaseUrl/$placeId');

      if (kDebugMode) {
        print('[GooglePlaces] 🌐 Calling NEW Place Details API');
      }
      
      final response = await _client.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        print('[GooglePlaces] Details response: ${response.statusCode}');
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('[GooglePlaces] ❌ Details API error: ${response.statusCode} - ${response.body}');
        }
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      
      final displayName = data['displayName'] as Map<String, dynamic>?;
      final name = displayName?['text'] as String? ?? '';
      final formattedAddress = data['formattedAddress'] as String? ?? '';
      
      final location = data['location'] as Map<String, dynamic>?;
      final lat = (location?['latitude'] as num?)?.toDouble();
      final lng = (location?['longitude'] as num?)?.toDouble();

      // Extract city and state from addressComponents
      String city = '';
      String state = '';
      String district = '';
      final components = data['addressComponents'] as List<dynamic>? ?? [];
      for (final comp in components) {
        final c = comp as Map<String, dynamic>;
        final types = (c['types'] as List<dynamic>?)
                ?.map((t) => t as String)
                .toList() ??
            [];
        final longName = c['longText'] as String? ?? '';

        if (types.contains('locality')) {
          city = longName;
        } else if (types.contains('administrative_area_level_2')) {
          district = longName;
        } else if (types.contains('administrative_area_level_1')) {
          state = longName;
        }
      }

      // Fallback: use name as city if locality not found
      if (city.isEmpty) city = name;

      final locResult = LocationResult(
        name: city,
        state: state,
        district: district.isNotEmpty ? district : null,
        lat: lat,
        lng: lng,
        address: formattedAddress,
        locationType: LocationType.city,
        isMajorHub: false,
      );
      
      if (kDebugMode) {
        print('[GooglePlaces] ✅ Details parsed: $city, $state (lat=$lat, lng=$lng)');
      }
      
      return locResult;
    } catch (e) {
      if (kDebugMode) {
        print('[GooglePlaces] ❌ Details exception: $e');
      }
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// A prediction from Google Places Autocomplete.
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}
