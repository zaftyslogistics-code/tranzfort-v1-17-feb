import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../bot/services/bot_tts_service.dart';
import '../../models/route_model.dart';
import '../../providers/active_navigation_state.dart';
import '../../providers/navigation_providers.dart';
import '../../services/nearby_pois_service.dart';

class ActiveNavigationScreen extends ConsumerStatefulWidget {
  final RouteModel route;
  final String originCity;
  final String destCity;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String? tripId;
  final String? loadContext;

  const ActiveNavigationScreen({
    super.key,
    required this.route,
    required this.originCity,
    required this.destCity,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.tripId,
    this.loadContext,
  });

  @override
  ConsumerState<ActiveNavigationScreen> createState() =>
      _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState
    extends ConsumerState<ActiveNavigationScreen> {
  final _mapController = MapController();
  final _tts = BotTtsService();
  StreamSubscription<Position>? _positionSub;

  LatLng? _currentPosition;
  double _currentSpeed = 0;
  double _currentHeading = 0;
  late RouteModel _route;
  int _currentStepIndex = 0;
  double _remainingDistanceKm = 0;
  double _remainingDurationMin = 0;
  bool _isRerouting = false;
  bool _arrived = false;
  bool _voiceMuted = false;
  int _closestPolylineIdx = 0; // GPS-9.4: split point for completed vs remaining
  late bool _nightMode; // GPS-13.2: night mode map

  static const _offRouteThresholdM = 200.0;
  static const _dayTileUrl = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const _nightTileUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png';
  static const _stepAdvanceThresholdM = 80.0;
  static const _distanceCalc = Distance();

  // GPS-7.2: Multi-distance approach prompts before each turn
  static const _approachThresholdsM = [3000.0, 1000.0, 500.0, 200.0];
  final Set<String> _announcedApproaches = {}; // "stepIdx_thresholdM"
  String? _lastSpokenText; // GPS-7.6: for repeat button

  // LOC-6: Distance milestone announcements (km remaining thresholds)
  static const _distanceMilestones = [50.0, 25.0, 10.0, 5.0, 1.0];
  final Set<double> _announcedMilestones = {};

  // LOC-6: Rest suggestion after 4 hours of driving
  static const _restSuggestionAfterMin = 240.0; // 4 hours
  DateTime? _drivingStartTime;
  bool _restSuggestionGiven = false;

  // LOC-7: Nearby POI layer
  List<NearbyPoi> _nearbyPois = [];
  NearbyPoi? _selectedPoi;
  DateTime? _lastPoiFetch;
  final Set<String> _announcedWeighBridgePoiIds = {};

  @override
  void initState() {
    super.initState();
    // GPS-13.2: Auto-detect night mode (6 PM to 6 AM)
    final hour = DateTime.now().hour;
    _nightMode = hour >= 18 || hour < 6;
    _route = widget.route;
    _remainingDistanceKm = _route.distanceKm;
    _remainingDurationMin = _route.durationMin;
    WakelockPlus.enable();
    _drivingStartTime = DateTime.now();
    _tts.initialize().then((_) {
      _voiceMuted = _tts.isMuted;
      // Speak initial instruction
      if (_route.steps.isNotEmpty) {
        _speakInstruction(_route.steps.first);
      }
    });
    _startLocationTracking();
    _startTrackingSession();
    // LOC-7: Initial POI fetch around origin
    _fetchNearbyPois(widget.originLat, widget.originLng);
    // Start global navigation state for persistent banner
    ref.read(activeNavigationProvider.notifier).start(
      originCity: widget.originCity,
      destCity: widget.destCity,
      distanceKm: _route.distanceKm,
      durationMin: _route.durationMin,
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _tts.stop();
    // Stop tracking if still active (user popped without pressing Stop)
    final tracking = ref.read(trackingServiceProvider);
    if (tracking.isTracking) tracking.stopSession();
    // Clear global navigation state
    ref.read(activeNavigationProvider.notifier).stop();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _startTrackingSession() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    try {
      final tracking = ref.read(trackingServiceProvider);
      await tracking.startSession(
        truckerId: userId,
        loadId: widget.tripId,
        originCity: widget.originCity,
        originLat: widget.originLat,
        originLng: widget.originLng,
        destCity: widget.destCity,
        destLat: widget.destLat,
        destLng: widget.destLng,
        routeDistanceKm: _route.distanceKm,
        routeDurationMin: _route.durationMin,
      );
    } catch (_) {
      // Non-critical — navigation works without tracking
    }
  }

  String _voiceLanguage() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode
        .toLowerCase();
    return code.startsWith('hi') ? 'hi' : 'en';
  }

  String _stepVoiceInstruction(NavigationStep step) {
    return _voiceLanguage() == 'hi' ? step.hindiInstruction : step.instruction;
  }

  void _speakInstruction(NavigationStep step) {
    if (_voiceMuted) return;
    final lang = _voiceLanguage();
    final prompt = _stepVoiceInstruction(step);
    _lastSpokenText = prompt;
    _tts.speak(prompt, lang);
  }

  // GPS-7.2: Speak approach prompt at specific distances before the next turn
  void _checkApproachPrompts(LatLng pos) {
    if (_voiceMuted || _arrived) return;
    if (_currentStepIndex >= _route.steps.length) return;

    final step = _route.steps[_currentStepIndex];
    if (step.geometry.isEmpty) return;

    final stepEnd = step.geometry.last;
    final distToTurnM = _distanceCalc.as(LengthUnit.Meter, pos, stepEnd);

    for (final threshold in _approachThresholdsM) {
      final key = '${_currentStepIndex}_$threshold';
      if (_announcedApproaches.contains(key)) continue;
      if (distToTurnM <= threshold && distToTurnM > _stepAdvanceThresholdM) {
        _announcedApproaches.add(key);
        final lang = _voiceLanguage();
        final distText = threshold >= 1000
            ? '${(threshold / 1000).toStringAsFixed(0)} ${lang == 'hi' ? 'kilometer' : 'kilometers'}'
            : '${threshold.round()} ${lang == 'hi' ? 'meter' : 'meters'}';
        String direction = '';
        if (step.maneuverType == 'turn') {
          if (step.modifier == 'left') {
            direction = lang == 'hi' ? 'baayein mudna hai' : 'turn left';
          } else if (step.modifier == 'right') {
            direction = lang == 'hi' ? 'daayein mudna hai' : 'turn right';
          } else {
            direction = lang == 'hi' ? 'mudna hai' : 'prepare to turn';
          }
        } else if (step.maneuverType == 'roundabout') {
          direction = lang == 'hi'
              ? 'gol chakkar aane wala hai'
              : 'roundabout ahead';
        } else {
          direction = lang == 'hi' ? 'aagey badhein' : 'continue straight';
        }
        final prompt =
            lang == 'hi' ? '$distText mein $direction' : 'In $distText, $direction';
        _lastSpokenText = prompt;
        _tts.speak(prompt, lang);
        break; // One prompt at a time
      }
    }
  }

  // GPS-7.6: Repeat last spoken instruction
  void _repeatLastInstruction() {
    final lang = _voiceLanguage();
    if (_lastSpokenText != null) {
      _tts.speak(_lastSpokenText!, lang);
    } else if (_currentStepIndex < _route.steps.length) {
      _speakInstruction(_route.steps[_currentStepIndex]);
    }
  }

  void _startLocationTracking() async {
    // GPS-13.6: Check GPS availability before starting
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.navGpsDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.navPermDeniedForever);
      return;
    }
    if (permission == LocationPermission.denied && mounted) {
      AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.navPermDenied);
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        final newPos = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentPosition = newPos;
          _currentSpeed = position.speed * 3.6; // m/s → km/h
          _currentHeading = position.heading;
        });

        _updateNavigation(newPos);

        // GPS-9.4: Update closest polyline index for route split
        _closestPolylineIdx = _findClosestPolylineIndex(newPos);

        // Auto-follow
        try {
          _mapController.move(newPos, _mapController.camera.zoom);
          _mapController.rotate(-position.heading);
        } catch (_) {}
      },
      onError: (e) {
        if (mounted) {
          AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.navGpsError(e.toString()));
        }
      },
    );
  }

  void _updateNavigation(LatLng pos) {
    if (_arrived || _isRerouting) return;

    // Check if arrived at destination
    final distToDest = _distanceCalc.as(
      LengthUnit.Meter,
      pos,
      LatLng(widget.destLat, widget.destLng),
    );
    if (distToDest < 100) {
      setState(() => _arrived = true);
      HapticFeedback.heavyImpact();
      final lang = _voiceLanguage();
      _tts.speak(
        lang == 'hi'
            ? 'Aap apni manzil par pahunch gaye hain'
            : 'You have arrived at your destination',
        lang,
      );
      // Complete tracking session
      ref.read(trackingServiceProvider).stopSession();
      // Log navigation history
      final userId = ref.read(authServiceProvider).currentUser?.id;
      if (userId != null) {
        ref.read(trackingServiceProvider).logNavigation(
          userId: userId,
          originCity: widget.originCity,
          destCity: widget.destCity,
          originLat: widget.originLat,
          originLng: widget.originLng,
          destLat: widget.destLat,
          destLng: widget.destLng,
          distanceKm: _route.distanceKm,
          durationMin: _route.durationMin,
        );
      }
      return;
    }

    // Update remaining distance/time estimate
    final newRemainingKm = distToDest / 1000;
    setState(() {
      _remainingDistanceKm = newRemainingKm;
      if (_currentSpeed > 5) {
        _remainingDurationMin = (_remainingDistanceKm / _currentSpeed) * 60;
      }
    });
    // Update global navigation state for persistent banner
    ref.read(activeNavigationProvider.notifier).update(
      remainingDistanceKm: _remainingDistanceKm,
      remainingDurationMin: _remainingDurationMin,
      currentSpeedKmh: _currentSpeed,
    );

    // LOC-6: Distance milestone TTS announcements
    _checkDistanceMilestones(newRemainingKm);

    // LOC-6: Rest suggestion after 4 hours driving
    _checkRestSuggestion();

    // LOC-7: Refresh POIs every 10km of travel
    final now = DateTime.now();
    if (_lastPoiFetch == null ||
        now.difference(_lastPoiFetch!).inMinutes >= 10) {
      _fetchNearbyPois(pos.latitude, pos.longitude);
    }

    // LOC-057: Weigh bridge warning TTS
    _checkWeighBridgeWarning(pos);

    // GPS-7.2: Check approach prompts before turn
    _checkApproachPrompts(pos);

    // Check step advancement
    if (_currentStepIndex < _route.steps.length) {
      final step = _route.steps[_currentStepIndex];
      if (step.geometry.isNotEmpty) {
        final stepEnd = step.geometry.last;
        final distToStepEnd = _distanceCalc.as(
          LengthUnit.Meter, pos, stepEnd,
        );
        if (distToStepEnd < _stepAdvanceThresholdM &&
            _currentStepIndex < _route.steps.length - 1) {
          setState(() => _currentStepIndex++);
          HapticFeedback.lightImpact();
          // Voice: speak next instruction
          _speakInstruction(_route.steps[_currentStepIndex]);
        }
      }
    }

    // Off-route detection
    final distToRoute = _minDistanceToPolyline(pos, _route.polyline);
    if (distToRoute > _offRouteThresholdM) {
      _reroute(pos);
    }
  }

  double _minDistanceToPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    double minDist = double.infinity;
    // Sample every 5th point for performance
    for (var i = 0; i < polyline.length; i += 5) {
      final d = _distanceCalc.as(LengthUnit.Meter, point, polyline[i]);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  // GPS-9.4: Find the closest point index on the polyline to the current position
  int _findClosestPolylineIndex(LatLng pos) {
    final poly = _route.polyline;
    if (poly.isEmpty) return 0;
    double minDist = double.infinity;
    int bestIdx = _closestPolylineIdx; // Start from last known to avoid jumping back
    // Search forward from current index (+ small lookback for GPS jitter)
    final start = (_closestPolylineIdx - 5).clamp(0, poly.length - 1);
    for (var i = start; i < poly.length; i++) {
      final d = _distanceCalc.as(LengthUnit.Meter, pos, poly[i]);
      if (d < minDist) {
        minDist = d;
        bestIdx = i;
      }
      // Early exit: if distance starts increasing significantly, stop
      if (d > minDist + 500 && i > bestIdx + 20) break;
    }
    return bestIdx;
  }

  // LOC-7: Fetch nearby truck POIs around current position
  Future<void> _fetchNearbyPois(double lat, double lng) async {
    _lastPoiFetch = DateTime.now();
    const delta = 0.3; // ~33km bounding box
    try {
      final svc = ref.read(nearbyPoisServiceProvider);
      final pois = await svc.fetchNearby(
        minLat: lat - delta,
        maxLat: lat + delta,
        minLng: lng - delta,
        maxLng: lng + delta,
        limit: 25,
      );
      if (mounted) setState(() => _nearbyPois = pois);
    } catch (_) {}
  }

  // LOC-6: Announce distance milestones (50km, 25km, 10km, 5km, 1km remaining)
  void _checkDistanceMilestones(double remainingKm) {
    if (_voiceMuted) return;
    final lang = _voiceLanguage();
    for (final milestone in _distanceMilestones) {
      if (_announcedMilestones.contains(milestone)) continue;
      // Trigger when we cross below the milestone
      if (remainingKm <= milestone) {
        _announcedMilestones.add(milestone);
        final String text;
        if (lang == 'hi') {
          if (milestone >= 50) {
            text = 'Manzil abhi ${milestone.round()} kilometer door hai';
          } else if (milestone >= 10) {
            text = 'Manzil sirf ${milestone.round()} kilometer reh gayi';
          } else if (milestone >= 5) {
            text = 'Manzil paanch kilometer door hai. Taiyaar rahein';
          } else {
            text = 'Manzil ek kilometer door hai. Pahunchne wale hain';
          }
        } else {
          if (milestone >= 50) {
            text = 'Destination is still ${milestone.round()} kilometers away';
          } else if (milestone >= 10) {
            text = 'Only ${milestone.round()} kilometers remaining';
          } else if (milestone >= 5) {
            text = 'Destination is five kilometers away. Stay ready';
          } else {
            text = 'Destination is one kilometer away. Almost there';
          }
        }
        _tts.speak(text, lang);
        break; // Announce one milestone at a time
      }
    }
  }

  // LOC-6: Suggest rest after 4 hours of continuous driving
  void _checkRestSuggestion() {
    if (_voiceMuted || _restSuggestionGiven || _drivingStartTime == null) return;
    final drivingMinutes =
        DateTime.now().difference(_drivingStartTime!).inMinutes.toDouble();
    if (drivingMinutes >= _restSuggestionAfterMin) {
      _restSuggestionGiven = true;
      final lang = _voiceLanguage();
      _tts.speak(
        lang == 'hi'
            ? 'Aap ${_restSuggestionAfterMin.round()} minute se zyada drive kar rahe hain. '
                'Kripya aaram karein aur paani piyein.'
            : 'You have been driving for more than ${_restSuggestionAfterMin.round()} minutes. '
                'Please take a short break and drink water.',
        lang,
      );
    }
  }

  // LOC-057: Weigh bridge voice warning from nearby POI feed
  void _checkWeighBridgeWarning(LatLng pos) {
    if (_voiceMuted || _nearbyPois.isEmpty) return;
    final lang = _voiceLanguage();
    const warnDistanceM = 800.0;

    for (final poi in _nearbyPois) {
      if (poi.category != 'weigh_bridge') continue;
      if (_announcedWeighBridgePoiIds.contains(poi.id)) continue;

      final distanceM = _distanceCalc.as(
        LengthUnit.Meter,
        pos,
        LatLng(poi.lat, poi.lng),
      );

      if (distanceM <= warnDistanceM) {
        _announcedWeighBridgePoiIds.add(poi.id);
        final prompt = lang == 'hi'
            ? 'Aage weigh bridge aa raha hai. Speed kam rakhein aur documents ready rakhein.'
            : 'Weigh bridge ahead. Slow down and keep your documents ready.';
        _lastSpokenText = prompt;
        _tts.speak(prompt, lang);
        break;
      }
    }
  }

  Future<void> _reroute(LatLng currentPos) async {
    if (_isRerouting) return;
    setState(() => _isRerouting = true);

    try {
      final routing = ref.read(routingServiceProvider);
      final routes = await routing.getRoute(
        origin: currentPos,
        destination: LatLng(widget.destLat, widget.destLng),
        alternatives: false,
      );

      if (!mounted) return;
      if (routes.isNotEmpty) {
        setState(() {
          _route = routes.first;
          _currentStepIndex = 0;
          _remainingDistanceKm = _route.distanceKm;
          _remainingDurationMin = _route.durationMin;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Silently fail — keep old route
    } finally {
      if (mounted) setState(() => _isRerouting = false);
    }
  }

  void _stopNavigation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.navStopNavigation),
        content: Text(AppLocalizations.of(context)!.navStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.navContinue),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Cancel tracking session
              ref.read(trackingServiceProvider).cancelSession();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.navStop),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _currentStepIndex < _route.steps.length
        ? _route.steps[_currentStepIndex]
        : null;
    final nextStep = _currentStepIndex + 1 < _route.steps.length
        ? _route.steps[_currentStepIndex + 1]
        : null;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ??
                  LatLng(widget.originLat, widget.originLng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: _nightMode ? _nightTileUrl : _dayTileUrl,
                subdomains: _nightMode ? const ['a', 'b', 'c', 'd'] : const [],
                userAgentPackageName: 'com.tranzfort.app',
              ),
              // GPS-9.4: Completed route (gray) + remaining route (teal)
              PolylineLayer(
                polylines: [
                  // Completed portion (gray)
                  if (_closestPolylineIdx > 0)
                    Polyline(
                      points: _route.polyline.sublist(0, _closestPolylineIdx + 1),
                      strokeWidth: 4,
                      color: Colors.grey.shade400,
                    ),
                  // Remaining portion (teal)
                  Polyline(
                    points: _route.polyline.sublist(_closestPolylineIdx),
                    strokeWidth: 5,
                    color: AppColors.brandTeal,
                  ),
                ],
              ),
              // Destination marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(widget.destLat, widget.destLng),
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.flag, color: Colors.red, size: 28),
                  ),
                  // Current position
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: Transform.rotate(
                        angle: _currentHeading * (3.14159 / 180),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.blue,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
              // LOC-7: Nearby POI markers
              if (_nearbyPois.isNotEmpty)
                MarkerLayer(
                  markers: _nearbyPois.map((poi) {
                    final isSelected = _selectedPoi?.id == poi.id;
                    return Marker(
                      point: LatLng(poi.lat, poi.lng),
                      width: isSelected ? 52 : 36,
                      height: isSelected ? 52 : 36,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedPoi =
                              _selectedPoi?.id == poi.id ? null : poi;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandOrange
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandOrangeDark
                                  : AppColors.borderDefault,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              poi.markerEmoji,
                              style: TextStyle(
                                  fontSize: isSelected ? 22 : 16),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // LOC-7: Selected POI info card
          if (_selectedPoi != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 12,
              right: 12,
              child: _PoiInfoCard(
                poi: _selectedPoi!,
                onClose: () => setState(() => _selectedPoi = null),
              ),
            ),

          // Speed badge (top-left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🚛 ${_currentSpeed.round()} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // ETA badge (top-right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_remainingDistanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatDuration(_remainingDurationMin),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rerouting indicator
          if (_isRerouting)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.navRerouting,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // Arrived overlay
          if (_arrived)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.brandTeal, size: 64),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)!.navArrived,
                            style: AppTypography.h2Section),
                        const SizedBox(height: 4),
                        Text(AppLocalizations.of(context)!.navArrivedAt(widget.destCity),
                            style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brandTeal),
                          child: Text(AppLocalizations.of(context)!.done),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom instruction card
          if (!_arrived)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current instruction
                        if (currentStep != null) ...[
                          Row(
                            children: [
                              _buildManeuverIcon(currentStep.maneuverType,
                                  currentStep.modifier),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentStep.hindiInstruction,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (currentStep.roadName != null)
                                      Text(
                                        currentStep.roadName!,
                                        style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                currentStep.distanceText,
                                style: AppTypography.h3Subsection.copyWith(
                                    color: AppColors.brandTeal),
                              ),
                            ],
                          ),
                        ],

                        // Next step preview
                        if (nextStep != null) ...[
                          const Divider(height: 16),
                          Row(
                            children: [
                              const SizedBox(width: 4),
                              Text('Then: ',
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textTertiary)),  // Keep English — TTS handles Hindi
                              Expanded(
                                child: Text(
                                  '${nextStep.distanceText} — ${nextStep.hindiInstruction}',
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Bottom controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              _voiceMuted ? Icons.volume_off : Icons.volume_up,
                              _voiceMuted ? AppLocalizations.of(context)!.navUnmute : AppLocalizations.of(context)!.navMute,
                              () {
                                setState(() => _voiceMuted = !_voiceMuted);
                                if (_voiceMuted) _tts.stop();
                              },
                            ),
                            _buildControlButton(
                              Icons.replay,
                              AppLocalizations.of(context)!.navRepeat,
                              _repeatLastInstruction,
                            ),
                            _buildControlButton(
                              Icons.refresh,
                              AppLocalizations.of(context)!.navReroute,
                              () {
                                if (_currentPosition != null) {
                                  _reroute(_currentPosition!);
                                }
                              },
                            ),
                            _buildControlButton(
                              Icons.list,
                              AppLocalizations.of(context)!.navSteps,
                              _showStepsList,
                            ),
                            _buildControlButton(
                              Icons.close,
                              AppLocalizations.of(context)!.navStop,
                              _stopNavigation,
                              color: AppColors.error,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManeuverIcon(String type, String? modifier) {
    IconData icon;
    switch (type) {
      case 'turn':
        icon = modifier?.contains('left') == true
            ? Icons.turn_left
            : Icons.turn_right;
        break;
      case 'roundabout':
        icon = Icons.roundabout_left;
        break;
      case 'merge':
        icon = Icons.merge;
        break;
      case 'arrive':
        icon = Icons.flag;
        break;
      case 'depart':
        icon = Icons.play_arrow;
        break;
      default:
        icon = Icons.arrow_upward;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.brandTealLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.brandTeal, size: 24),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final c = color ?? AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: AppTypography.caption.copyWith(color: c, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showStepsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _route.steps.length,
          itemBuilder: (ctx, i) {
            final step = _route.steps[i];
            final isCurrent = i == _currentStepIndex;
            final isPast = i < _currentStepIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.brandTealLight
                    : isPast
                        ? AppColors.scaffoldBg
                        : AppColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: isCurrent
                    ? Border.all(color: AppColors.brandTeal)
                    : null,
              ),
              child: Row(
                children: [
                  _buildManeuverIcon(step.maneuverType, step.modifier),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.hindiInstruction,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isPast
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (step.roadName != null)
                          Text(step.roadName!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  Text(step.distanceText,
                      style: AppTypography.caption.copyWith(
                          color: isPast
                              ? AppColors.textTertiary
                              : AppColors.textSecondary)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// LOC-7: POI info card shown when a map marker is tapped
class _PoiInfoCard extends StatelessWidget {
  final NearbyPoi poi;
  final VoidCallback onClose;

  const _PoiInfoCard({required this.poi, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            // Category emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandOrangeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(poi.markerEmoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 10),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    poi.name,
                    style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandTealLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          poi.categoryLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (poi.is24x7) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '24x7',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (poi.dieselPrice != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${poi.dieselPrice!.toStringAsFixed(0)}/L',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.brandOrange,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (poi.avgRating != null && poi.avgRating! > 0) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star,
                            size: 11, color: AppColors.brandOrange),
                        Text(
                          poi.avgRating!.toStringAsFixed(1),
                          style: AppTypography.caption,
                        ),
                      ],
                    ],
                  ),
                  if (poi.phone != null && poi.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      poi.phone!,
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            // Close button
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              color: AppColors.textTertiary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
