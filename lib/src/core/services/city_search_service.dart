import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Location type — drives icon and search priority.
enum LocationType {
  city,
  town,
  village,
  colony,
  industrialArea,
  transportNagar,
  postOffice,
  district,
  port,
  mandi,
  dryPort,
  transportHub,
}

class LocationResult {
  final String name;
  final String state;
  final String? district;
  final String? pincode;
  final double? lat;
  final double? lng;
  final LocationType locationType;
  final bool isMajorHub;
  final String? parentCity;
  final String? address;
  final double? distanceKm;

  const LocationResult({
    required this.name,
    required this.state,
    this.district,
    this.pincode,
    this.lat,
    this.lng,
    this.locationType = LocationType.city,
    this.isMajorHub = false,
    this.parentCity,
    this.address,
    this.distanceKm,
  });

  /// Legacy compat: keep `type` as string getter
  String get type => locationType.name;

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'city';
    return LocationResult(
      name: json['name'] as String,
      state: json['state'] as String,
      district: json['district'] as String?,
      pincode: json['pincode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      locationType: _parseType(typeStr),
      isMajorHub: json['is_major_hub'] as bool? ?? false,
      parentCity: json['parent_city'] as String?,
      address: json['address'] as String?,
    );
  }

  /// Build from compact pincode_index.json array:
  /// [name, pincode, district, state, lat, lng]
  factory LocationResult.fromPincodeArray(List<dynamic> arr) {
    return LocationResult(
      name: arr[0] as String,
      pincode: arr[1] as String,
      district: arr[2] as String? ?? '',
      state: arr[3] as String,
      lat: (arr[4] as num?)?.toDouble(),
      lng: (arr[5] as num?)?.toDouble(),
      locationType: LocationType.postOffice,
      isMajorHub: false,
    );
  }

  LocationResult copyWith({double? distanceKm}) {
    return LocationResult(
      name: name,
      state: state,
      district: district,
      pincode: pincode,
      lat: lat,
      lng: lng,
      locationType: locationType,
      isMajorHub: isMajorHub,
      parentCity: parentCity,
      address: address,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  bool get hasCoordinates => lat != null && lng != null;

  /// Subtitle shown in dropdown: district + state + pincode
  String get subtitle {
    final parts = <String>[];
    if (district != null && district!.isNotEmpty) parts.add(district!);
    parts.add(state);
    if (pincode != null && pincode!.isNotEmpty) parts.add(pincode!);
    return parts.join(', ');
  }

  @override
  String toString() => '$name, $state';

  static LocationType _parseType(String s) {
    switch (s) {
      case 'transport_hub':
        return LocationType.transportHub;
      case 'industrial_zone':
        return LocationType.industrialArea;
      case 'port':
        return LocationType.port;
      case 'mandi':
        return LocationType.mandi;
      case 'dry_port':
        return LocationType.dryPort;
      case 'district_hq':
        return LocationType.district;
      case 'town':
        return LocationType.town;
      default:
        return LocationType.city;
    }
  }
}

class CitySearchService {
  // ── Hub locations (indian_locations.json, ~70 entries) ──
  List<LocationResult>? _hubs;
  List<List<String>>? _hubAliases;

  // ── Pincode index (pincode_index.json, ~10K entries) ──
  List<LocationResult>? _pincodes;
  // Pincode → index in _pincodes for O(1) lookup
  Map<String, int>? _pincodeMap;

  bool _pincodeLoaded = false;

  // ── Load hub locations (always loaded, small file) ──
  Future<void> _ensureHubsLoaded() async {
    if (_hubs != null) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/indian_locations.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final list = data['locations'] as List<dynamic>;
      _hubs = list
          .map((e) => LocationResult.fromJson(e as Map<String, dynamic>))
          .toList();
      _hubAliases = list.map((e) {
        final aliases = e['aliases'] as List<dynamic>?;
        return aliases?.map((a) => (a as String).toLowerCase()).toList() ?? <String>[];
      }).toList();
    } catch (_) {
      _hubs = [];
      _hubAliases = [];
    }
  }

  // ── Load pincode index (lazy, larger file ~700KB) ──
  Future<void> _ensurePincodesLoaded() async {
    if (_pincodeLoaded) return;
    _pincodeLoaded = true;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/pincode_index.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      _pincodes = list
          .map((e) => LocationResult.fromPincodeArray(e as List<dynamic>))
          .toList();
      // Build pincode → first-index map
      _pincodeMap = {};
      for (var i = 0; i < _pincodes!.length; i++) {
        final pc = _pincodes![i].pincode ?? '';
        if (pc.isNotEmpty && !_pincodeMap!.containsKey(pc)) {
          _pincodeMap![pc] = i;
        }
      }
    } catch (_) {
      _pincodes = [];
      _pincodeMap = {};
    }
  }

  // ── Main search ──
  Future<List<LocationResult>> search(String query, {int limit = 10}) async {
    await _ensureHubsLoaded();

    if (query.trim().isEmpty) return [];

    final q = query.toLowerCase().trim();

    // 1. Pincode exact match (6 digits) — instant, no full scan needed
    if (RegExp(r'^\d{6}$').hasMatch(q)) {
      return _searchByPincode(q, limit: limit);
    }

    // 2. Hub search (always fast, ~70 items)
    final hubResults = _searchHubs(q, limit: limit);

    // 3. If query >= 3 chars, also search pincode index
    if (q.length >= 3) {
      await _ensurePincodesLoaded();
      final pcResults = _searchPincodes(q, limit: limit, exclude: hubResults);

      // Merge: hubs first (higher priority), then pincode results
      final merged = [...hubResults, ...pcResults];
      return merged.take(limit).toList();
    }

    return hubResults.take(limit).toList();
  }

  List<LocationResult> _searchHubs(String q, {required int limit}) {
    final hubs = _hubs!;
    final aliases = _hubAliases!;
    final scored = <_ScoredResult>[];

    for (var i = 0; i < hubs.length; i++) {
      final loc = hubs[i];
      final nameLower = loc.name.toLowerCase();
      final stateLower = loc.state.toLowerCase();
      final districtLower = loc.district?.toLowerCase() ?? '';
      final hubAliases = aliases[i];

      int score = 0;
      if (nameLower == q) {
        score = 100;
      } else if (nameLower.startsWith(q)) {
        score = 80;
      } else if (nameLower.contains(q)) {
        score = 60;
      } else if (hubAliases.any((a) => a == q)) {
        score = 75;
      } else if (hubAliases.any((a) => a.startsWith(q))) {
        score = 55;
      } else if (hubAliases.any((a) => a.contains(q))) {
        score = 45;
      } else if (districtLower.contains(q)) {
        score = 35;
      } else if (stateLower.contains(q)) {
        score = 20;
      }

      if (score > 0) {
        if (loc.isMajorHub) score += 10;
        scored.add(_ScoredResult(loc, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.location).toList();
  }

  List<LocationResult> _searchPincodes(
    String q, {
    required int limit,
    required List<LocationResult> exclude,
  }) {
    final pincodes = _pincodes!;
    final excludeNames = exclude.map((e) => e.name.toLowerCase()).toSet();
    final scored = <_ScoredResult>[];

    for (final loc in pincodes) {
      final nameLower = loc.name.toLowerCase();
      // Skip if already in hub results
      if (excludeNames.contains(nameLower)) continue;

      final districtLower = loc.district?.toLowerCase() ?? '';
      final stateLower = loc.state.toLowerCase();
      final pincodeLower = loc.pincode ?? '';

      int score = 0;
      if (nameLower == q) {
        score = 90;
      } else if (nameLower.startsWith(q)) {
        score = 70;
      } else if (nameLower.contains(q)) {
        score = 50;
      } else if (districtLower == q) {
        score = 40;
      } else if (districtLower.startsWith(q)) {
        score = 30;
      } else if (districtLower.contains(q)) {
        score = 20;
      } else if (stateLower.contains(q)) {
        score = 10;
      } else if (pincodeLower.startsWith(q)) {
        score = 35;
      }

      if (score > 0) {
        scored.add(_ScoredResult(loc, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.location).toList();
  }

  Future<List<LocationResult>> _searchByPincode(String pincode,
      {required int limit}) async {
    await _ensurePincodesLoaded();
    final pincodes = _pincodes!;
    final results = <LocationResult>[];
    for (final loc in pincodes) {
      if (loc.pincode == pincode) {
        results.add(loc);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  /// Look up a location by exact city name (case-insensitive).
  /// Returns the first match with coordinates, or null.
  Future<LocationResult?> getLocationByName(String cityName) async {
    await _ensureHubsLoaded();
    final q = cityName.toLowerCase().trim();
    for (final loc in _hubs!) {
      if (loc.name.toLowerCase() == q && loc.hasCoordinates) return loc;
    }
    // Check aliases
    for (var i = 0; i < _hubs!.length; i++) {
      final aliases = _hubAliases![i];
      if (aliases.any((a) => a == q) && _hubs![i].hasCoordinates) {
        return _hubs![i];
      }
    }
    // Fallback: search pincode index
    await _ensurePincodesLoaded();
    for (final loc in _pincodes!) {
      if (loc.name.toLowerCase() == q && loc.hasCoordinates) return loc;
    }
    return null;
  }

  /// Look up by pincode — returns all matching entries.
  Future<List<LocationResult>> getByPincode(String pincode) async {
    return _searchByPincode(pincode.trim(), limit: 20);
  }

  /// Find nearest locations to given coordinates.
  /// Searches hub list first, then pincode index.
  Future<List<LocationResult>> getNearby(
    double lat,
    double lng, {
    int limit = 5,
    double maxKm = 50,
  }) async {
    await _ensureHubsLoaded();
    await _ensurePincodesLoaded();

    final all = [..._hubs!, ..._pincodes!];
    final scored = <_ScoredResult>[];

    for (final loc in all) {
      if (!loc.hasCoordinates) continue;
      final d = _haversineKm(lat, lng, loc.lat!, loc.lng!);
      if (d <= maxKm) {
        // Score: closer = higher (invert distance, max 100)
        final score = math.max(0, (100 - d * 2).round());
        scored.add(_ScoredResult(loc.copyWith(distanceKm: d), score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.location).toList();
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;
}

class _ScoredResult {
  final LocationResult location;
  final int score;

  const _ScoredResult(this.location, this.score);
}
