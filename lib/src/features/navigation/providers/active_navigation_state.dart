import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveNavigationInfo {
  final String originCity;
  final String destCity;
  final double remainingDistanceKm;
  final double remainingDurationMin;
  final double? currentSpeedKmh;

  const ActiveNavigationInfo({
    required this.originCity,
    required this.destCity,
    required this.remainingDistanceKm,
    required this.remainingDurationMin,
    this.currentSpeedKmh,
  });

  ActiveNavigationInfo copyWith({
    double? remainingDistanceKm,
    double? remainingDurationMin,
    double? currentSpeedKmh,
  }) {
    return ActiveNavigationInfo(
      originCity: originCity,
      destCity: destCity,
      remainingDistanceKm: remainingDistanceKm ?? this.remainingDistanceKm,
      remainingDurationMin: remainingDurationMin ?? this.remainingDurationMin,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
    );
  }

  String get etaText {
    if (remainingDurationMin < 60) {
      return '${remainingDurationMin.round()} min';
    }
    final hours = (remainingDurationMin / 60).floor();
    final mins = (remainingDurationMin % 60).round();
    return '${hours}h ${mins}m';
  }

  String get distanceText {
    if (remainingDistanceKm < 1) {
      return '${(remainingDistanceKm * 1000).round()} m';
    }
    return '${remainingDistanceKm.toStringAsFixed(1)} km';
  }
}

class ActiveNavigationNotifier extends StateNotifier<ActiveNavigationInfo?> {
  ActiveNavigationNotifier() : super(null);

  void start({
    required String originCity,
    required String destCity,
    required double distanceKm,
    required double durationMin,
  }) {
    state = ActiveNavigationInfo(
      originCity: originCity,
      destCity: destCity,
      remainingDistanceKm: distanceKm,
      remainingDurationMin: durationMin,
    );
  }

  void update({
    double? remainingDistanceKm,
    double? remainingDurationMin,
    double? currentSpeedKmh,
  }) {
    if (state == null) return;
    state = state!.copyWith(
      remainingDistanceKm: remainingDistanceKm,
      remainingDurationMin: remainingDurationMin,
      currentSpeedKmh: currentSpeedKmh,
    );
  }

  void stop() {
    state = null;
  }

  bool get isActive => state != null;
}

final activeNavigationProvider =
    StateNotifierProvider<ActiveNavigationNotifier, ActiveNavigationInfo?>(
  (ref) => ActiveNavigationNotifier(),
);
