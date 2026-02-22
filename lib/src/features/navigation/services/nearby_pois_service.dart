import 'package:supabase_flutter/supabase_flutter.dart';

/// A single truck-relevant Point of Interest near the route.
class NearbyPoi {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;
  final String? phone;
  final bool is24x7;
  final double? dieselPrice;
  final double? avgRating;

  const NearbyPoi({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.phone,
    this.is24x7 = false,
    this.dieselPrice,
    this.avgRating,
  });

  factory NearbyPoi.fromJson(Map<String, dynamic> json) => NearbyPoi(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'other',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        phone: json['phone'] as String?,
        is24x7: json['is_24x7'] as bool? ?? false,
        dieselPrice: (json['diesel_price'] as num?)?.toDouble(),
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
      );

  /// Icon label for the map marker.
  String get markerEmoji {
    switch (category) {
      case 'fuel_station':
        return '⛽';
      case 'dhaba':
        return '🍽';
      case 'truck_parking':
        return '🅿';
      case 'mechanic':
        return '🔧';
      case 'tyre_shop':
        return '🔩';
      case 'rest_area':
        return '🛏';
      case 'toll_plaza':
        return '🚧';
      case 'weigh_bridge':
        return '⚖';
      default:
        return '📍';
    }
  }

  String get categoryLabel {
    const labels = {
      'fuel_station': 'Fuel',
      'dhaba': 'Dhaba',
      'truck_parking': 'Parking',
      'mechanic': 'Mechanic',
      'tyre_shop': 'Tyre',
      'rest_area': 'Rest',
      'toll_plaza': 'Toll',
      'weigh_bridge': 'Weigh',
    };
    return labels[category] ?? category;
  }
}

/// Fetches truck-relevant POIs near a bounding box from Supabase.
/// Falls back to empty list on error (offline-safe).
class NearbyPoisService {
  final SupabaseClient _supabase;

  NearbyPoisService(this._supabase);

  /// Returns POIs within a lat/lng bounding box.
  /// [categories] filters by category; pass null for all truck-relevant ones.
  Future<List<NearbyPoi>> fetchNearby({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    List<String>? categories,
    int limit = 30,
  }) async {
    try {
      final cats = categories ??
          [
            'fuel_station',
            'dhaba',
            'truck_parking',
            'mechanic',
            'tyre_shop',
            'rest_area',
            'toll_plaza',
            'weigh_bridge',
          ];

      var query = _supabase
          .from('pois')
          .select('id,name,category,lat,lng,phone,is_24x7,diesel_price,avg_rating')
          .gte('lat', minLat)
          .lte('lat', maxLat)
          .gte('lng', minLng)
          .lte('lng', maxLng)
          .inFilter('category', cats)
          .limit(limit);

      final response = await query;
      return (response as List)
          .map((e) => NearbyPoi.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
