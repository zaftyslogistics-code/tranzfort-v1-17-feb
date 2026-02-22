import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../models/route_model.dart';
import '../../providers/navigation_providers.dart';
import '../../services/routing_service.dart';
import '../../services/trip_costing_service.dart';
import '../../../../core/utils/map_launcher.dart';

class RoutePreviewScreen extends ConsumerStatefulWidget {
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String originCity;
  final String destCity;
  final String? loadContext;
  final String? tripId;
  final String? originState;
  final String? bodyType;
  final double? loadWeightKg;

  const RoutePreviewScreen({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.originCity,
    required this.destCity,
    this.loadContext,
    this.tripId,
    this.originState,
    this.bodyType,
    this.loadWeightKg,
  });

  @override
  ConsumerState<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends ConsumerState<RoutePreviewScreen> {
  final _mapController = MapController();
  List<RouteModel>? _routes;
  int _selectedRouteIndex = 0;
  bool _isLoading = true;
  String? _error;
  TripCostEstimate? _costEstimate;

  // GPS-13.2: Night mode auto-detect
  bool get _isNightMode {
    final h = DateTime.now().hour;
    return h >= 18 || h < 6;
  }

  LatLng get _origin => LatLng(widget.originLat, widget.originLng);
  LatLng get _dest => LatLng(widget.destLat, widget.destLng);

  RouteModel? get _selectedRoute =>
      _routes != null && _routes!.isNotEmpty ? _routes![_selectedRouteIndex] : null;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routing = ref.read(routingServiceProvider);
      final routes = await routing.getRoute(
        origin: _origin,
        destination: _dest,
        alternatives: true,
      );

      if (!mounted) return;
      setState(() {
        _routes = routes;
        _isLoading = false;
      });

      // Fit map to route bounds
      _fitMapToRoute();

      // Calculate trip cost in background
      _fetchCosting(routes.first.distanceKm);
    } on RoutingException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to calculate route: $e';
        _isLoading = false;
      });
    }
  }

  void _fitMapToRoute() {
    if (_selectedRoute == null) return;

    final points = [_origin, _dest, ..._selectedRoute!.polyline];
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(minLat, minLng),
              LatLng(maxLat, maxLng),
            ),
            padding: const EdgeInsets.all(50),
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> _fetchCosting(double distanceKm) async {
    try {
      final costing = ref.read(tripCostingServiceProvider);
      final estimate = await costing.estimate(
        distanceKm: distanceKm,
        bodyType: widget.bodyType,
        loadWeightKg: widget.loadWeightKg ?? 0,
        originState: widget.originState,
      );
      if (mounted) setState(() => _costEstimate = estimate);
    } catch (_) {
      // Non-critical — costing is informational
    }
  }

  static const _disclaimerKey = 'nav_disclaimer_accepted';

  void _startNavigation() async {
    if (_selectedRoute == null) return;
    HapticFeedback.mediumImpact();

    // GPS-13.1: Show legal disclaimer on first use
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_disclaimerKey) ?? false;
    if (!accepted && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.brandOrange),
              SizedBox(width: 8),
              Text('Navigation Disclaimer'),
            ],
          ),
          content: const Text(
            'TranZfort navigation is for guidance only. '
            'Always follow actual road signs and traffic rules. '
            'Routes may not account for all road restrictions, '
            'low bridges, or weight limits.\n\n'
            'Drive safely. Do not operate the phone while driving.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandTeal),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await prefs.setBool(_disclaimerKey, true);
    }

    if (!mounted) return;
    context.push('/navigation/active', extra: {
      'route': _selectedRoute,
      'originCity': widget.originCity,
      'destCity': widget.destCity,
      'originLat': widget.originLat,
      'originLng': widget.originLng,
      'destLat': widget.destLat,
      'destLng': widget.destLng,
      'tripId': widget.tripId,
      'loadContext': widget.loadContext,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('${widget.originCity} → ${widget.destCity}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Open in Google Maps',
            onPressed: () => MapLauncher.openGoogleMapsRoute(
              originLat: widget.originLat,
              originLng: widget.originLng,
              destLat: widget.destLat,
              destLng: widget.destLng,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _fetchRoute,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildRouteView(),
    );
  }

  Widget _buildRouteView() {
    final route = _selectedRoute;
    if (route == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Map
        Expanded(
          flex: 3,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (_origin.latitude + _dest.latitude) / 2,
                (_origin.longitude + _dest.longitude) / 2,
              ),
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: _isNightMode
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: _isNightMode ? const ['a', 'b', 'c', 'd'] : const [],
                userAgentPackageName: 'com.tranzfort.app',
              ),
              // Route polylines (unselected routes in gray)
              if (_routes != null && _routes!.length > 1)
                for (var i = 0; i < _routes!.length; i++)
                  if (i != _selectedRouteIndex)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routes![i].polyline,
                          strokeWidth: 4,
                          color: AppColors.textTertiary.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
              // Selected route polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.polyline,
                    strokeWidth: 5,
                    color: AppColors.brandTeal,
                  ),
                ],
              ),
              // Markers
              MarkerLayer(
                markers: [
                  Marker(
                    point: _origin,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.trip_origin,
                        color: Colors.green, size: 28),
                  ),
                  Marker(
                    point: _dest,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.flag,
                        color: Colors.red, size: 28),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Route summary
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Load context
                if (widget.loadContext != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brandTealLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping,
                            size: 16, color: AppColors.brandTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(widget.loadContext!,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.brandTealDark)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Route summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.originCity} → ${widget.destCity}',
                        style: AppTypography.h3Subsection,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStat(Icons.straighten, route.distanceText),
                          const SizedBox(width: 20),
                          _buildStat(Icons.schedule, route.durationText),
                          const SizedBox(width: 20),
                          _buildStat(Icons.access_time,
                              'ETA ${TimeOfDay.fromDateTime(route.eta).format(context)}'),
                        ],
                      ),
                      // V4-2: Trip cost estimate
                      if (_costEstimate != null) ...[                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.brandTealLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              _buildCostChip(Icons.local_gas_station, 'Diesel', _costEstimate!.dieselText),
                              const SizedBox(width: 12),
                              _buildCostChip(Icons.toll, 'Tolls', _costEstimate!.tollText),
                              const SizedBox(width: 12),
                              _buildCostChip(Icons.account_balance_wallet, 'Total', _costEstimate!.totalText),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_costEstimate!.mileageText} avg | ${_costEstimate!.tollPlazaCount} toll${_costEstimate!.tollPlazaCount != 1 ? 's' : ''} est.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                      if (route.viaRoads != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Via: ${route.viaRoads}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${route.steps.length} steps',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Alternate routes
                if (_routes != null && _routes!.length > 1) ...[
                  const SizedBox(height: 12),
                  Text('Alternate Routes',
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...List.generate(_routes!.length, (i) {
                    final r = _routes![i];
                    final isSelected = i == _selectedRouteIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedRouteIndex = i);
                        _fitMapToRoute();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brandTealLight
                              : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brandTeal
                                : AppColors.borderDefault,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? AppColors.brandTeal
                                  : AppColors.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text('Route ${i + 1}',
                                style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text(r.distanceText,
                                style: AppTypography.caption),
                            const SizedBox(width: 12),
                            Text(r.durationText,
                                style: AppTypography.caption),
                            if (i == 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.brandTeal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Fastest',
                                    style: AppTypography.caption.copyWith(
                                        color: Colors.white, fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 16),

                // Start navigation button
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _startNavigation,
                    icon: const Icon(Icons.navigation, size: 20),
                    label: const Text('Start Navigation',
                        style: TextStyle(fontSize: 16)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCostChip(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.brandTeal),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.brandTealDark,
          )),
          Text(label, style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: AppColors.textSecondary,
          )),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.brandTeal),
        const SizedBox(width: 4),
        Text(text, style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }

  // GPS-13.7: Skeleton loader while route is being calculated
  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        // Map placeholder
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.brandTeal),
                  SizedBox(height: 12),
                  Text('Calculating route...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        // Summary skeleton
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBar(width: 200, height: 20),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _shimmerBar(width: 70, height: 14),
                    const SizedBox(width: 20),
                    _shimmerBar(width: 70, height: 14),
                    const SizedBox(width: 20),
                    _shimmerBar(width: 90, height: 14),
                  ],
                ),
                const SizedBox(height: 16),
                _shimmerBar(width: double.infinity, height: 60),
                const SizedBox(height: 16),
                _shimmerBar(width: double.infinity, height: 52),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBar({required double height, double? width}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
