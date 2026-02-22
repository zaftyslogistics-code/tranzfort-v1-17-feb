import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight state exposed to the persistent tracking banner.
class TrackingState {
  final bool isActive;
  final String? originCity;
  final String? destCity;
  final double? lastSpeedKmh;
  final bool isPaused;

  const TrackingState({
    this.isActive = false,
    this.originCity,
    this.destCity,
    this.lastSpeedKmh,
    this.isPaused = false,
  });

  static const idle = TrackingState();
}

class TrackingService {
  final SupabaseClient _supabase;
  final Battery _battery = Battery();
  StreamSubscription<Position>? _positionSub;
  Timer? _batchTimer;
  final List<Map<String, dynamic>> _pendingPings = [];
  String? _activeSessionId;
  String? _activeTruckerId;

  // Auto-pause: track consecutive zero-speed pings
  DateTime? _lastMovedAt;
  bool _isPaused = false;
  static const _autoPauseDuration = Duration(minutes: 5);

  /// Observable state for the persistent tracking banner.
  final ValueNotifier<TrackingState> state =
      ValueNotifier(TrackingState.idle);

  TrackingService(this._supabase);

  String? get activeSessionId => _activeSessionId;
  String? get activeTruckerId => _activeTruckerId;
  bool get isTracking => _activeSessionId != null;

  /// Start a new tracking session and begin sending location pings.
  Future<String> startSession({
    required String truckerId,
    String? loadId,
    required String originCity,
    double? originLat,
    double? originLng,
    required String destCity,
    double? destLat,
    double? destLng,
    double? routeDistanceKm,
    double? routeDurationMin,
  }) async {
    // Create session in DB
    final response = await _supabase.from('tracking_sessions').insert({
      'trucker_id': truckerId,
      if (loadId != null) 'load_id': loadId,
      'origin_city': originCity,
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      'dest_city': destCity,
      if (destLat != null) 'dest_lat': destLat,
      if (destLng != null) 'dest_lng': destLng,
      if (routeDistanceKm != null) 'route_distance_km': routeDistanceKm,
      if (routeDurationMin != null) 'route_duration_min': routeDurationMin,
      'status': 'active',
    }).select('id').single();

    _activeSessionId = response['id'] as String;
    _activeTruckerId = truckerId;
    _lastMovedAt = DateTime.now();
    _isPaused = false;

    // Update banner state
    state.value = TrackingState(
      isActive: true,
      originCity: originCity,
      destCity: destCity,
    );

    // Start GPS stream
    _startLocationStream(truckerId);

    // Batch upload timer (every 60 seconds)
    _batchTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _flushPings();
    });

    return _activeSessionId!;
  }

  void _startLocationStream(String truckerId) {
    // Use Android foreground service settings for background tracking
    final LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TranZfort Navigation',
          notificationText: 'Tracking your trip in the background',
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      );
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      if (_activeSessionId == null) return;

      final speedKmh = position.speed * 3.6;

      // Auto-pause logic: skip pings when stationary for >5 min
      if (speedKmh > 2.0) {
        _lastMovedAt = DateTime.now();
        if (_isPaused) {
          _isPaused = false;
          state.value = TrackingState(
            isActive: true,
            originCity: state.value.originCity,
            destCity: state.value.destCity,
            lastSpeedKmh: speedKmh,
            isPaused: false,
          );
        }
      } else if (_lastMovedAt != null &&
          DateTime.now().difference(_lastMovedAt!) > _autoPauseDuration) {
        if (!_isPaused) {
          _isPaused = true;
          state.value = TrackingState(
            isActive: true,
            originCity: state.value.originCity,
            destCity: state.value.destCity,
            lastSpeedKmh: 0,
            isPaused: true,
          );
        }
        return; // Skip ping when auto-paused
      }

      // Read battery info
      int? batteryLevel;
      bool? isCharging;
      try {
        batteryLevel = await _battery.batteryLevel;
        final batteryState = await _battery.batteryState;
        isCharging = batteryState == BatteryState.charging ||
            batteryState == BatteryState.full;
      } catch (_) {}

      _pendingPings.add({
        'session_id': _activeSessionId,
        'trucker_id': truckerId,
        'lat': position.latitude,
        'lng': position.longitude,
        'speed_kmh': speedKmh,
        'heading': position.heading,
        'accuracy_m': position.accuracy,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (isCharging != null) 'is_charging': isCharging,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Update banner state with speed
      state.value = TrackingState(
        isActive: true,
        originCity: state.value.originCity,
        destCity: state.value.destCity,
        lastSpeedKmh: speedKmh,
        isPaused: false,
      );
    });
  }

  Future<void> _flushPings() async {
    if (_pendingPings.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pendingPings);
    _pendingPings.clear();

    try {
      await _supabase.from('location_pings').insert(batch);
    } catch (_) {
      // Re-queue on failure (offline resilience)
      _pendingPings.insertAll(0, batch);
    }
  }

  /// Stop the active tracking session.
  Future<void> stopSession() async {
    if (_activeSessionId == null) return;

    // Flush remaining pings
    await _flushPings();

    // Update session status
    try {
      await _supabase.from('tracking_sessions').update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _activeSessionId!);
    } catch (_) {}

    _cleanup();
  }

  /// Cancel the active tracking session.
  Future<void> cancelSession() async {
    if (_activeSessionId == null) return;

    try {
      await _supabase.from('tracking_sessions').update({
        'status': 'cancelled',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _activeSessionId!);
    } catch (_) {}

    _cleanup();
  }

  void _cleanup() {
    _positionSub?.cancel();
    _positionSub = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    _pendingPings.clear();
    _activeSessionId = null;
    _activeTruckerId = null;
    _lastMovedAt = null;
    _isPaused = false;
    state.value = TrackingState.idle;
  }

  /// Log a navigation to history.
  Future<void> logNavigation({
    required String userId,
    required String originCity,
    required String destCity,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    double? distanceKm,
    double? durationMin,
  }) async {
    await _supabase.from('navigation_history').insert({
      'user_id': userId,
      'origin_city': originCity,
      'dest_city': destCity,
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      if (destLat != null) 'dest_lat': destLat,
      if (destLng != null) 'dest_lng': destLng,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (durationMin != null) 'duration_min': durationMin,
    });
  }

  /// Get recent navigation history for a user.
  Future<List<Map<String, dynamic>>> getRecentNavigations(String userId,
      {int limit = 10}) async {
    final response = await _supabase
        .from('navigation_history')
        .select()
        .eq('user_id', userId)
        .order('navigated_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  void dispose() {
    _cleanup();
    state.dispose();
  }
}
