import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String loadId;
  final String originCity;
  final String destCity;

  const LiveTrackingScreen({
    super.key,
    required this.loadId,
    required this.originCity,
    required this.destCity,
  });

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final _mapController = MapController();
  final _supabase = Supabase.instance.client;

  LatLng? _truckerPosition;
  double _truckerSpeed = 0;
  double _truckerHeading = 0;
  String? _sessionStatus;
  DateTime? _lastPingTime;
  RealtimeChannel? _channel;
  bool _isLoading = true;
  String? _error;
  String? _truckerName;
  String? _truckerPhone;
  final List<_TrackingEvent> _timelineEvents = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Find active tracking session for this load
      final sessions = await _supabase
          .from('tracking_sessions')
          .select()
          .eq('load_id', widget.loadId)
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1);

      if (sessions.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'No active tracking session for this load. The trucker may not have started navigation yet.';
        });
        return;
      }

      final session = sessions.first;
      final sessionId = session['id'] as String;
      _sessionStatus = session['status'] as String?;

      // GPS-9.8: Fetch trucker name & phone
      final truckerId = session['user_id'] as String?;
      if (truckerId != null) {
        try {
          final trucker = await _supabase
              .from('truckers')
              .select('id, profiles!truckers_id_fkey(full_name, phone)')
              .eq('id', truckerId)
              .maybeSingle();
          if (trucker != null) {
            final profile = trucker['profiles'] as Map<String, dynamic>?;
            _truckerName = profile?['full_name'] as String?;
            _truckerPhone = profile?['phone'] as String?;
          }
        } catch (_) {}
      }

      // Get latest ping
      final pings = await _supabase
          .from('location_pings')
          .select()
          .eq('session_id', sessionId)
          .order('recorded_at', ascending: false)
          .limit(1);

      if (pings.isNotEmpty) {
        final ping = pings.first;
        _truckerPosition = LatLng(
          (ping['lat'] as num).toDouble(),
          (ping['lng'] as num).toDouble(),
        );
        _truckerSpeed = (ping['speed_kmh'] as num?)?.toDouble() ?? 0;
        _truckerHeading = (ping['heading'] as num?)?.toDouble() ?? 0;
        _lastPingTime = DateTime.tryParse(ping['recorded_at'] as String? ?? '');
      }

      // GPS-9.6: Build timeline from recent location pings
      final recentPings = await _supabase
          .from('location_pings')
          .select()
          .eq('session_id', sessionId)
          .order('recorded_at', ascending: false)
          .limit(25);
      _timelineEvents
        ..clear()
        ..addAll(_buildTimelineFromPings(List<Map<String, dynamic>>.from(recentPings)));

      setState(() => _isLoading = false);

      // Subscribe to real-time pings
      _subscribeToLivePings(sessionId);

      // Center map on trucker
      if (_truckerPosition != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(_truckerPosition!, 12);
          } catch (_) {}
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load tracking data: $e';
      });
    }
  }

  void _subscribeToLivePings(String sessionId) {
    _channel = _supabase
        .channel('tracking_$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'location_pings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (!mounted) return;

            final lat = (newRow['lat'] as num?)?.toDouble();
            final lng = (newRow['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) return;

            setState(() {
              _truckerPosition = LatLng(lat, lng);
              final prevSpeed = _truckerSpeed;
              _truckerSpeed = (newRow['speed_kmh'] as num?)?.toDouble() ?? 0;
              _truckerHeading = (newRow['heading'] as num?)?.toDouble() ?? 0;
              _lastPingTime =
                  DateTime.tryParse(newRow['recorded_at'] as String? ?? '') ?? DateTime.now();

              final events = _eventsFromPing(
                newRow,
                previousSpeed: prevSpeed,
              );
              for (final event in events) {
                _timelineEvents.insert(0, event);
              }
              if (_timelineEvents.length > 20) {
                _timelineEvents.removeRange(20, _timelineEvents.length);
              }
            });

            // Auto-follow
            try {
              _mapController.move(_truckerPosition!, _mapController.camera.zoom);
            } catch (_) {}
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('${widget.originCity} → ${widget.destCity}'),
        actions: [
          if (_sessionStatus == 'active')
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.white),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandTeal))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: AppTypography.bodyMedium),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _loadInitialData();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Map
                    Expanded(
                      flex: 3,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _truckerPosition ?? const LatLng(20.5937, 78.9629),
                          initialZoom: _truckerPosition != null ? 12 : 5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.tranzfort.app',
                          ),
                          if (_truckerPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _truckerPosition!,
                                  width: 44,
                                  height: 44,
                                  child: Transform.rotate(
                                    angle: _truckerHeading * (3.14159 / 180),
                                    child: const Icon(
                                      Icons.local_shipping,
                                      color: AppColors.brandTeal,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Info panel
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.originCity} → ${widget.destCity}',
                              style: AppTypography.h3Subsection,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildInfoChip(Icons.speed, '${_truckerSpeed.round()} km/h'),
                                const SizedBox(width: 12),
                                if (_lastPingTime != null)
                                  _buildInfoChip(
                                    Icons.access_time,
                                    'Updated ${_timeAgo(_lastPingTime!)}',
                                  ),
                              ],
                            ),
                            // GPS-9.8: Call / Message trucker
                            if (_truckerPhone != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (_truckerName != null) ...[
                                    const Icon(Icons.person, size: 16, color: AppColors.brandTeal),
                                    const SizedBox(width: 4),
                                    Text(_truckerName!, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                  ],
                                  OutlinedButton.icon(
                                    onPressed: () => launchUrl(Uri.parse('tel:$_truckerPhone')),
                                    icon: const Icon(Icons.call, size: 16),
                                    label: const Text('Call'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.brandTeal,
                                      side: const BorderSide(color: AppColors.brandTeal),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => launchUrl(Uri.parse('sms:$_truckerPhone')),
                                    icon: const Icon(Icons.message, size: 16),
                                    label: const Text('SMS'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.brandOrange,
                                      side: const BorderSide(color: AppColors.brandOrange),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_truckerPosition != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '📍 ${_truckerPosition!.latitude.toStringAsFixed(4)}, ${_truckerPosition!.longitude.toStringAsFixed(4)}',
                                style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                              ),
                            ],
                            if (_timelineEvents.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('Timeline', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 150),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _timelineEvents.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final e = _timelineEvents[index];
                                    return Row(
                                      children: [
                                        Icon(e.icon, size: 14, color: e.color),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            e.message,
                                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                          ),
                                        ),
                                        Text(
                                          _timeAgo(e.at),
                                          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandTeal),
          const SizedBox(width: 4),
          Text(text, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  List<_TrackingEvent> _buildTimelineFromPings(List<Map<String, dynamic>> pingsDesc) {
    final events = <_TrackingEvent>[];
    if (pingsDesc.isEmpty) return events;

    final pings = pingsDesc.reversed.toList();
    double? prevSpeed;
    DateTime? prevTime;
    for (final ping in pings) {
      final at = DateTime.tryParse(ping['recorded_at'] as String? ?? '');
      if (at == null) continue;

      final speed = (ping['speed_kmh'] as num?)?.toDouble() ?? 0;
      events.addAll(_eventsFromPing(ping, previousSpeed: prevSpeed, atOverride: at));

      if (prevTime != null && at.difference(prevTime).inMinutes > 10) {
        events.add(
          _TrackingEvent(
            message: 'Network gap detected (${at.difference(prevTime).inMinutes} min)',
            at: at,
            icon: Icons.signal_wifi_off,
            color: AppColors.warning,
          ),
        );
      }

      prevSpeed = speed;
      prevTime = at;
    }

    final out = events.reversed.toList();
    return out.length > 20 ? out.sublist(0, 20) : out;
  }

  List<_TrackingEvent> _eventsFromPing(
    Map<String, dynamic> ping, {
    required double? previousSpeed,
    DateTime? atOverride,
  }) {
    final events = <_TrackingEvent>[];
    final at = atOverride ?? DateTime.tryParse(ping['recorded_at'] as String? ?? '') ?? DateTime.now();
    final speed = (ping['speed_kmh'] as num?)?.toDouble() ?? 0;
    final battery = (ping['battery_level'] as num?)?.toDouble();

    events.add(
      _TrackingEvent(
        message: 'Location updated (${speed.round()} km/h)',
        at: at,
        icon: Icons.my_location,
        color: AppColors.brandTeal,
      ),
    );

    if (previousSpeed != null && previousSpeed <= 2 && speed > 5) {
      events.add(
        _TrackingEvent(
          message: 'Truck started moving',
          at: at,
          icon: Icons.play_arrow,
          color: Colors.green,
        ),
      );
    }

    if (previousSpeed != null && previousSpeed > 5 && speed <= 2) {
      events.add(
        _TrackingEvent(
          message: 'Truck stopped / idle',
          at: at,
          icon: Icons.pause_circle,
          color: AppColors.warning,
        ),
      );
    }

    if (battery != null && battery < 15) {
      events.add(
        _TrackingEvent(
          message: 'Low battery (${battery.round()}%)',
          at: at,
          icon: Icons.battery_alert,
          color: AppColors.error,
        ),
      );
    }

    return events;
  }
}

class _TrackingEvent {
  final String message;
  final DateTime at;
  final IconData icon;
  final Color color;

  const _TrackingEvent({
    required this.message,
    required this.at,
    required this.icon,
    required this.color,
  });
}
