/// Master truck specification from the `truck_models` Supabase table.
/// Contains make, model, dimensions, weight, and mileage data used for
/// truck-aware routing and trip costing.
class TruckModelSpec {
  final String id;
  final String make;
  final String model;
  final String? variant;
  final String bodyType;
  final int axles;
  final int tyres;
  final int gvwKg;
  final int payloadKg;
  final int? kerbWeightKg;
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final double? mileageEmptyKmpl;
  final double? mileageLoadedKmpl;
  final bool isActive;

  const TruckModelSpec({
    required this.id,
    required this.make,
    required this.model,
    this.variant,
    required this.bodyType,
    required this.axles,
    required this.tyres,
    required this.gvwKg,
    required this.payloadKg,
    this.kerbWeightKg,
    this.lengthM,
    this.widthM,
    this.heightM,
    this.mileageEmptyKmpl,
    this.mileageLoadedKmpl,
    this.isActive = true,
  });

  factory TruckModelSpec.fromJson(Map<String, dynamic> json) {
    return TruckModelSpec(
      id: json['id'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      variant: json['variant'] as String?,
      bodyType: json['body_type'] as String,
      axles: json['axles'] as int,
      tyres: json['tyres'] as int,
      gvwKg: json['gvw_kg'] as int,
      payloadKg: json['payload_kg'] as int,
      kerbWeightKg: json['kerb_weight_kg'] as int?,
      lengthM: (json['length_m'] as num?)?.toDouble(),
      widthM: (json['width_m'] as num?)?.toDouble(),
      heightM: (json['height_m'] as num?)?.toDouble(),
      mileageEmptyKmpl: (json['mileage_empty_kmpl'] as num?)?.toDouble(),
      mileageLoadedKmpl: (json['mileage_loaded_kmpl'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Display name: "Tata Signa 4923.S" or "Tata Signa 4923.S (HCV)"
  String get displayName {
    final base = '$make $model';
    return variant != null ? '$base ($variant)' : base;
  }

  /// Short summary for truck card: "10T | 3 Axles | 3.8m H"
  String get specSummary {
    final parts = <String>[];
    parts.add('${(payloadKg / 1000).toStringAsFixed(0)}T');
    parts.add('$axles Axle${axles > 1 ? 's' : ''}');
    if (heightM != null) parts.add('${heightM!.toStringAsFixed(1)}m H');
    return parts.join(' | ');
  }

  /// Interpolate mileage between empty and loaded based on current load weight.
  /// Returns km/L for the given load weight in kg.
  double dynamicMileage(double loadWeightKg) {
    final empty = mileageEmptyKmpl ?? 5.0;
    final loaded = mileageLoadedKmpl ?? 3.5;
    if (payloadKg <= 0) return loaded;
    final ratio = (loadWeightKg / payloadKg).clamp(0.0, 1.0);
    return empty - (empty - loaded) * ratio;
  }

  @override
  String toString() => displayName;
}
