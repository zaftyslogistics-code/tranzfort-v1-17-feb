import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../providers/navigation_providers.dart';
import '../../services/saved_places_service.dart';

class NavigationHomeScreen extends ConsumerStatefulWidget {
  final String? originCity;
  final String? destCity;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final String? tripId;
  final String? loadContext;

  const NavigationHomeScreen({
    super.key,
    this.originCity,
    this.destCity,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.tripId,
    this.loadContext,
  });

  @override
  ConsumerState<NavigationHomeScreen> createState() =>
      _NavigationHomeScreenState();
}

class _NavigationHomeScreenState extends ConsumerState<NavigationHomeScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  bool _isLocating = false;
  final bool _isFindingRoute = false;

  LatLng? _originLatLng;
  LatLng? _destLatLng;
  String? _originState;
  String? _destState;

  List<Map<String, dynamic>> _recentNavigations = [];
  List<SavedPlace> _savedPlaces = [];

  @override
  void initState() {
    super.initState();
    _prefillFromParams();
    _loadRecentAndSaved();
  }

  Future<void> _loadRecentAndSaved() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    try {
      final tracking = ref.read(trackingServiceProvider);
      final recents = await tracking.getRecentNavigations(userId, limit: 5);
      if (mounted) setState(() => _recentNavigations = recents);
    } catch (_) {}
    try {
      final savedSvc = ref.read(savedPlacesServiceProvider);
      final places = await savedSvc.getPlaces(userId);
      if (mounted) setState(() => _savedPlaces = places);
    } catch (_) {}
  }

  void _prefillFromParams() {
    if (widget.originCity != null) {
      _fromController.text = widget.originCity!;
    }
    if (widget.destCity != null) {
      _toController.text = widget.destCity!;
    }
    if (widget.originLat != null && widget.originLng != null) {
      _originLatLng = LatLng(widget.originLat!, widget.originLng!);
    }
    if (widget.destLat != null && widget.destLng != null) {
      _destLatLng = LatLng(widget.destLat!, widget.destLng!);
    }

    // If both are pre-filled with coordinates, go straight to route preview
    if (_originLatLng != null && _destLatLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _findRoute());
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppDialogs.showErrorSnackBar(
              context, 'Location services are disabled. Please enable GPS.');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppDialogs.showErrorSnackBar(context, 'Location permission denied');
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppDialogs.showErrorSnackBar(
              context, 'Location permission permanently denied. Enable in settings.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _originLatLng = LatLng(position.latitude, position.longitude);
        _fromController.text = '📍 Current Location';
      });

      // Try to reverse-match to a known city
      final cityService = ref.read(citySearchServiceProvider);
      final results = await cityService.search(
        '${position.latitude.toStringAsFixed(2)},${position.longitude.toStringAsFixed(2)}',
        limit: 1,
      );
      // Fallback: just keep "Current Location"
      if (results.isNotEmpty && mounted) {
        _fromController.text = '📍 ${results.first.name}';
        _originState = results.first.state;
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Could not get location: $e');
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _swapLocations() {
    HapticFeedback.lightImpact();
    final tmpText = _fromController.text;
    final tmpLatLng = _originLatLng;
    final tmpState = _originState;

    setState(() {
      _fromController.text = _toController.text;
      _toController.text = tmpText;
      _originLatLng = _destLatLng;
      _destLatLng = tmpLatLng;
      _originState = _destState;
      _destState = tmpState;
    });
  }

  Future<void> _findRoute() async {
    // Resolve coordinates if we only have city names
    final cityService = ref.read(citySearchServiceProvider);

    if (_originLatLng == null && _fromController.text.trim().isNotEmpty) {
      final name = _fromController.text.replaceAll('📍 ', '').trim();
      final loc = await cityService.getLocationByName(name);
      if (loc != null && loc.hasCoordinates) {
        _originLatLng = LatLng(loc.lat!, loc.lng!);
        _originState = loc.state;
      }
    }

    if (_destLatLng == null && _toController.text.trim().isNotEmpty) {
      final loc = await cityService.getLocationByName(_toController.text.trim());
      if (loc != null && loc.hasCoordinates) {
        _destLatLng = LatLng(loc.lat!, loc.lng!);
        _destState = loc.state;
      }
    }

    if (_originLatLng == null) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(
            context, 'Please select an origin location');
      }
      return;
    }
    if (_destLatLng == null) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(
            context, 'Please select a destination');
      }
      return;
    }

    if (!mounted) return;

    // Navigate to route preview
    context.push('/navigation/preview', extra: {
      'originLat': _originLatLng!.latitude,
      'originLng': _originLatLng!.longitude,
      'destLat': _destLatLng!.latitude,
      'destLng': _destLatLng!.longitude,
      'originCity': _fromController.text.replaceAll('📍 ', '').trim(),
      'destCity': _toController.text.trim(),
      'loadContext': widget.loadContext,
      'tripId': widget.tripId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('🧭 ${AppLocalizations.of(context)!.navNavigate}'),
        actions: [
          IconButton(
            onPressed: () => context.push('/navigation/history'),
            icon: const Icon(Icons.history),
            tooltip: AppLocalizations.of(context)!.navRecentDestinations,
          ),
          IconButton(
            onPressed: () => context.push('/navigation/add-place'),
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: AppLocalizations.of(context)!.navAddPlace,
          ),
          IconButton(
            onPressed: () => context.push('/navigation/saved-places'),
            icon: const Icon(Icons.bookmark),
            tooltip: AppLocalizations.of(context)!.navSavedPlaces,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Load context banner
            if (widget.loadContext != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandTealLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: AppColors.brandTeal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.loadContext!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.brandTealDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // FROM field
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
                  Row(
                    children: [
                      Text(AppLocalizations.of(context)!.navFrom, style: AppTypography.caption.copyWith(
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      )),
                      const Spacer(),
                      // Use current location button
                      TextButton.icon(
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 16),
                        label: Text(AppLocalizations.of(context)!.navMyLocation),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brandTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CityAutocompleteField(
                    controller: _fromController,
                    labelText: AppLocalizations.of(context)!.navOriginHint,
                    prefixIcon: Icons.trip_origin,
                    useGooglePlaces: true,
                    onCitySelected: (loc) {
                      if (loc.hasCoordinates) {
                        _originLatLng = LatLng(loc.lat!, loc.lng!);
                      } else {
                        _originLatLng = null;
                      }
                      _originState = loc.state;
                    },
                  ),
                ],
              ),
            ),

            // Swap button
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: IconButton(
                  onPressed: _swapLocations,
                  icon: const Icon(Icons.swap_vert, color: AppColors.brandTeal),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandTealLight,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ),

            // TO field
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
                  Text(AppLocalizations.of(context)!.navTo, style: AppTypography.caption.copyWith(
                    color: AppColors.brandOrange,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  )),
                  const SizedBox(height: 4),
                  CityAutocompleteField(
                    controller: _toController,
                    labelText: AppLocalizations.of(context)!.navDestHint,
                    prefixIcon: Icons.flag,
                    useGooglePlaces: true,
                    onCitySelected: (loc) {
                      if (loc.hasCoordinates) {
                        _destLatLng = LatLng(loc.lat!, loc.lng!);
                      } else {
                        _destLatLng = null;
                      }
                      _destState = loc.state;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Find Route button
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isFindingRoute ? null : _findRoute,
                icon: _isFindingRoute
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.route, size: 20),
                label: Text(AppLocalizations.of(context)!.navFindRoute, style: const TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recent Destinations
            if (_recentNavigations.isNotEmpty) ..._buildRecentSection(),

            // Saved Places
            if (_savedPlaces.isNotEmpty) ..._buildSavedPlacesSection(),

            // Quick tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.navQuickTips, style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 8),
                  _buildTip(Icons.my_location, AppLocalizations.of(context)!.navTipMyLocation),
                  _buildTip(Icons.swap_vert, AppLocalizations.of(context)!.navTipSwap),
                  _buildTip(Icons.local_shipping, AppLocalizations.of(context)!.navTipLoadAware),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecentSection() {
    return [
      Text('Recent Destinations', style: AppTypography.bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
      )),
      const SizedBox(height: 8),
      ...(_recentNavigations.map((nav) {
        final dest = nav['dest_city'] as String? ?? '';
        final origin = nav['origin_city'] as String? ?? '';
        final distKm = nav['distance_km'] as num?;
        final navigatedAt = DateTime.tryParse(nav['navigated_at']?.toString() ?? '');
        final ago = navigatedAt != null ? _timeAgo(navigatedAt) : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                _toController.text = dest;
                _destLatLng = null;
                if (origin.isNotEmpty) {
                  _fromController.text = origin;
                  _originLatLng = null;
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$origin → $dest',
                            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          if (distKm != null || ago.isNotEmpty)
                            Text(
                              [if (distKm != null) '${distKm.toStringAsFixed(0)} km', if (ago.isNotEmpty) ago].join(' · '),
                              style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      })),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildSavedPlacesSection() {
    return [
      Text('Saved Places', style: AppTypography.bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
      )),
      const SizedBox(height: 8),
      ...(_savedPlaces.map((place) {
        final icon = place.icon == 'home'
            ? Icons.home
            : place.icon == 'work'
                ? Icons.business
                : Icons.star;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                _toController.text = place.city;
                if (place.lat != null && place.lng != null) {
                  _destLatLng = LatLng(place.lat!, place.lng!);
                } else {
                  _destLatLng = null;
                }
                _destState = place.state;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.brandTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.label,
                            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            [place.city, if (place.state != null) place.state].join(', '),
                            style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        );
      })),
      const SizedBox(height: 16),
    ];
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            )),
          ),
        ],
      ),
    );
  }
}
