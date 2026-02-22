import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/truck_model_spec.dart';

/// Trip cost estimate containing fuel and toll breakdown.
class TripCostEstimate {
  final double distanceKm;
  final double dieselCost;
  final double tollCost;
  final double mileageUsed; // km/L used for calculation
  final double dieselPricePerLiter;
  final int tollPlazaCount;

  const TripCostEstimate({
    required this.distanceKm,
    required this.dieselCost,
    required this.tollCost,
    required this.mileageUsed,
    required this.dieselPricePerLiter,
    required this.tollPlazaCount,
  });

  double get totalCost => dieselCost + tollCost;

  String get dieselText => '₹${dieselCost.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  String get tollText => '₹${tollCost.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  String get totalText => '₹${totalCost.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
  String get mileageText => '${mileageUsed.toStringAsFixed(1)} km/L';
}

/// Calculates trip costs based on truck specs, distance, and load weight.
///
/// Formula: Total = (Distance / DynamicMileage) * DieselPrice + AxleTolls
class TripCostingService {
  final SupabaseClient _supabase;

  // Cache diesel prices (state → price/L)
  Map<String, double>? _dieselPrices;

  // Fallback national average
  static const _defaultDieselPrice = 87.50;

  // Average toll per plaza by axle count (₹, single journey, 2026 NHAI rates)
  static const _tollPerPlazaByAxles = <int, double>{
    2: 125,   // LCV (4-6 tyres)
    3: 270,   // 2-axle HCV (10 tyres)
    4: 410,   // 3-axle (14 tyres)
    5: 555,   // 4-axle (18 tyres)
    6: 680,   // 5-axle (22 tyres)
    7: 780,   // 6+ axle MAV
  };

  // Rough toll plaza density: 1 per ~60 km on NH
  static const _tollPlazaIntervalKm = 60.0;

  // Fallback mileage by body type when no truck spec available
  static const _fallbackMileage = <String, double>{
    'open': 4.0,
    'container': 3.5,
    'trailer': 3.0,
    'tanker': 3.5,
    'refrigerated': 3.2,
  };

  TripCostingService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Load diesel prices from Supabase. Cached after first call.
  Future<Map<String, double>> _loadDieselPrices() async {
    if (_dieselPrices != null) return _dieselPrices!;

    try {
      final response = await _supabase
          .from('diesel_prices')
          .select('state, price_per_liter');

      _dieselPrices = {};
      for (final row in response as List) {
        final map = row as Map<String, dynamic>;
        _dieselPrices![map['state'] as String] =
            (map['price_per_liter'] as num).toDouble();
      }
    } catch (_) {
      _dieselPrices = {};
    }

    return _dieselPrices!;
  }

  /// Get diesel price for a state. Falls back to national average.
  Future<double> getDieselPrice(String? state) async {
    if (state == null || state.isEmpty) return _defaultDieselPrice;
    final prices = await _loadDieselPrices();
    return prices[state] ?? _defaultDieselPrice;
  }

  /// Estimate trip cost.
  ///
  /// [distanceKm] — route distance from OSRM/Valhalla
  /// [truckSpec] — from master truck_models table (optional)
  /// [loadWeightKg] — current load weight (for dynamic mileage interpolation)
  /// [bodyType] — fallback if no truckSpec ('open', 'container', etc.)
  /// [originState] — for diesel price lookup
  Future<TripCostEstimate> estimate({
    required double distanceKm,
    TruckModelSpec? truckSpec,
    double loadWeightKg = 0,
    String? bodyType,
    String? originState,
  }) async {
    // 1. Determine mileage
    double mileage;
    if (truckSpec != null) {
      mileage = truckSpec.dynamicMileage(loadWeightKg);
    } else {
      mileage = _fallbackMileage[bodyType ?? 'open'] ?? 4.0;
    }

    // 2. Diesel cost
    final dieselPrice = await getDieselPrice(originState);
    final liters = distanceKm / mileage;
    final dieselCost = liters * dieselPrice;

    // 3. Toll cost (estimate based on distance and axle count)
    final axles = truckSpec?.axles ?? _axlesFromBodyType(bodyType);
    final tollPerPlaza = _tollPerPlazaByAxles[axles] ??
        _tollPerPlazaByAxles[3]!; // default to 3-axle HCV
    final tollPlazaCount = (distanceKm / _tollPlazaIntervalKm).floor();
    final tollCost = tollPlazaCount * tollPerPlaza;

    return TripCostEstimate(
      distanceKm: distanceKm,
      dieselCost: dieselCost,
      tollCost: tollCost,
      mileageUsed: mileage,
      dieselPricePerLiter: dieselPrice,
      tollPlazaCount: tollPlazaCount,
    );
  }

  /// Infer axle count from body type when no truck spec is available.
  int _axlesFromBodyType(String? bodyType) {
    switch (bodyType) {
      case 'trailer':
        return 4;
      case 'tanker':
        return 3;
      case 'container':
        return 3;
      case 'open':
        return 3;
      default:
        return 3;
    }
  }

  /// Invalidate cached diesel prices.
  void clearCache() {
    _dieselPrices = null;
  }
}
