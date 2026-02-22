import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Task 6.6: Matches toll plazas along a route polyline.
/// Uses Haversine distance to check if any polyline point is within
/// [matchRadiusM] meters of a toll plaza.
class TollMatchingService {
  static const _assetPath = 'assets/data/toll_plazas.json';
  static const double matchRadiusM = 500.0;

  List<TollPlaza>? _plazas;
  final Map<String, TollMatchResult> _cache = {};

  /// Load toll plaza data from bundled asset.
  Future<void> init() async {
    if (_plazas != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    final list = json.decode(raw) as List;
    _plazas = list.map((e) => TollPlaza.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Match toll plazas along a route polyline for a given axle count.
  /// Returns matched plazas and total cost.
  Future<TollMatchResult> matchTollsAlongRoute({
    required List<LatLng> polyline,
    required int axleCount,
  }) async {
    await init();

    // Cache key: hash of first/last point + axle count
    final cacheKey = '${polyline.first.latitude.toStringAsFixed(3)}'
        '_${polyline.first.longitude.toStringAsFixed(3)}'
        '_${polyline.last.latitude.toStringAsFixed(3)}'
        '_${polyline.last.longitude.toStringAsFixed(3)}'
        '_$axleCount';

    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final matched = <MatchedTollPlaza>[];

    for (final plaza in _plazas!) {
      final plazaPoint = LatLng(plaza.lat, plaza.lng);
      bool isNearRoute = false;

      // Check every Nth polyline point (skip some for performance)
      final step = math.max(1, polyline.length ~/ 500);
      for (var i = 0; i < polyline.length; i += step) {
        final dist = _haversineM(polyline[i], plazaPoint);
        if (dist <= matchRadiusM) {
          isNearRoute = true;
          break;
        }
      }

      if (isNearRoute) {
        final axleKey = axleCount.toString();
        final cost = plaza.rates[axleKey] ?? plaza.rates['2'] ?? 0;
        matched.add(MatchedTollPlaza(
          plaza: plaza,
          costForAxle: cost.toDouble(),
        ));
      }
    }

    final totalCost = matched.fold<double>(0, (sum, m) => sum + m.costForAxle);
    final result = TollMatchResult(
      matchedPlazas: matched,
      totalCost: totalCost,
      axleCount: axleCount,
    );

    _cache[cacheKey] = result;
    return result;
  }

  /// Haversine distance in meters between two LatLng points.
  static double _haversineM(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final h = sinDLat * sinDLat +
        math.cos(_toRad(a.latitude)) *
            math.cos(_toRad(b.latitude)) *
            sinDLng *
            sinDLng;
    return 2 * R * math.asin(math.sqrt(h));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}

/// A toll plaza from the dataset.
class TollPlaza {
  final String id;
  final String name;
  final String highway;
  final double lat;
  final double lng;
  final Map<String, num> rates; // axle count → rate in ₹

  const TollPlaza({
    required this.id,
    required this.name,
    required this.highway,
    required this.lat,
    required this.lng,
    required this.rates,
  });

  factory TollPlaza.fromJson(Map<String, dynamic> json) {
    final ratesRaw = json['rates'] as Map<String, dynamic>? ?? {};
    final rates = ratesRaw.map((k, v) => MapEntry(k, v as num));
    return TollPlaza(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      highway: json['highway'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      rates: rates,
    );
  }
}

/// A toll plaza matched along a route with its cost for the given axle count.
class MatchedTollPlaza {
  final TollPlaza plaza;
  final double costForAxle;

  const MatchedTollPlaza({required this.plaza, required this.costForAxle});
}

/// Result of matching tolls along a route.
class TollMatchResult {
  final List<MatchedTollPlaza> matchedPlazas;
  final double totalCost;
  final int axleCount;

  const TollMatchResult({
    required this.matchedPlazas,
    required this.totalCost,
    required this.axleCount,
  });

  String get totalCostText {
    final str = totalCost.round().toString();
    return '₹${str.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  }

  int get plazaCount => matchedPlazas.length;
}
