import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/cache/sqlite_cache.dart';

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
  // Task 9.5: Pings now stored in SQLite pending_pings table (not RAM)
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
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (_) {}

      // Task 9.5: Store ping in SQLite instead of in-memory list
      try {
        await CacheService.db.insert('pending_pings', {
          'session_id': _activeSessionId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'speed': speedKmh,
          'battery_level': batteryLevel,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('TrackingService: failed to store ping in SQLite: $e');
      }

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
    if (_activeSessionId == null) return;

    try {
      final db = CacheService.db;
      final rows = await db.query(
        'pending_pings',
        where: 'session_id = ?',
        whereArgs: [_activeSessionId],
        orderBy: 'timestamp ASC',
        limit: 100,
      );

      if (rows.isEmpty) return;

      // Convert SQLite rows to Supabase insert format
      final batch = rows.map((r) => {
        'session_id': r['session_id'],
        'trucker_id': _activeTruckerId,
        'lat': r['latitude'],
        'lng': r['longitude'],
        'speed_kmh': r['speed'],
        'heading': r['heading'],
        'battery_level': r['battery_level'],
        'recorded_at': DateTime.fromMillisecondsSinceEpoch(
          r['timestamp'] as int,
        ).toUtc().toIso8601String(),
      }).toList();

      await _supabase.from('location_pings').insert(batch);

      // Delete flushed rows from SQLite
      final ids = rows.map((r) => r['id']).toList();
      await db.delete(
        'pending_pings',
        where: 'id IN (${ids.map((_) => '?').join(',')})',
        whereArgs: ids,
      );

      debugPrint('TrackingService: flushed ${rows.length} pings');
    } catch (e) {
      debugPrint('TrackingService: flush failed (offline?): $e');
      // Pings remain in SQLite for next flush attempt
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

    await _cleanup();
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

    await _cleanup();
  }

  Future<void> _cleanup() async {
    _positionSub?.cancel();
    _positionSub = null;
    _batchTimer?.cancel();
    _batchTimer = null;
    // Clear pending pings from SQLite for this session
    if (_activeSessionId != null) {
      try {
        await CacheService.db.delete(
          'pending_pings',
          where: 'session_id = ?',
          whereArgs: [_activeSessionId],
        );
      } catch (_) {}
    }
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
