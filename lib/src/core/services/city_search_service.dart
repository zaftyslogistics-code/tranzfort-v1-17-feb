import 'dart:convert';
import 'package:flutter/services.dart';

class LocationResult {
  final String name;
  final String state;
  final String? district;
  final double? lat;
  final double? lng;
  final String type;
  final bool isMajorHub;

  const LocationResult({
    required this.name,
    required this.state,
    this.district,
    this.lat,
    this.lng,
    this.type = 'city',
    this.isMajorHub = false,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      name: json['name'] as String,
      state: json['state'] as String,
      district: json['district'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      type: json['type'] as String? ?? 'city',
      isMajorHub: json['is_major_hub'] as bool? ?? false,
    );
  }

  @override
  String toString() => '$name, $state';
}

class CitySearchService {
  List<LocationResult>? _locations;
  List<List<String>>? _aliasIndex;

  Future<void> _ensureLoaded() async {
    if (_locations != null) return;

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/indian_locations.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final locationsList = data['locations'] as List<dynamic>;

      _locations = locationsList
          .map((e) => LocationResult.fromJson(e as Map<String, dynamic>))
          .toList();

      _aliasIndex = locationsList.map((e) {
        final aliases = e['aliases'] as List<dynamic>?;
        return aliases?.map((a) => (a as String).toLowerCase()).toList() ?? [];
      }).toList();
    } catch (_) {
      // Fallback: empty list if asset not found yet
      _locations = [];
      _aliasIndex = [];
    }
  }

  Future<List<LocationResult>> search(String query, {int limit = 10}) async {
    await _ensureLoaded();

    if (query.trim().isEmpty) return [];

    final q = query.toLowerCase().trim();
    final locations = _locations!;
    final aliasIndex = _aliasIndex!;

    final scored = <_ScoredResult>[];

    for (var i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final nameLower = loc.name.toLowerCase();
      final stateLower = loc.state.toLowerCase();
      final districtLower = loc.district?.toLowerCase() ?? '';
      final aliases = aliasIndex[i];

      int score = 0;

      if (nameLower == q) {
        score = 100;
      } else if (nameLower.startsWith(q)) {
        score = 80;
      } else if (nameLower.contains(q)) {
        score = 60;
      } else if (stateLower.contains(q)) {
        score = 40;
      } else if (districtLower.contains(q)) {
        score = 35;
      } else if (aliases.any((a) => a.contains(q))) {
        score = 50;
      }

      if (score > 0) {
        if (loc.isMajorHub) score += 10;
        scored.add(_ScoredResult(loc, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.take(limit).map((s) => s.location).toList();
  }
}

class _ScoredResult {
  final LocationResult location;
  final int score;

  const _ScoredResult(this.location, this.score);
}
