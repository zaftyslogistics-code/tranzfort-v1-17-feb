import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/auth_service_provider.dart';
import '../../core/services/city_search_service.dart';
import '../../core/services/google_places_service.dart';

class CityAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(LocationResult)? onCitySelected;

  /// When true, appends Google Places API results below offline results.
  /// Use on Supplier PostLoadScreen and NavigationHomeScreen.
  /// Keep false (default) for Trucker FindLoadsScreen (offline only).
  final bool useGooglePlaces;

  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.textInputAction,
    this.validator,
    this.onCitySelected,
    this.useGooglePlaces = false,
  });

  @override
  ConsumerState<CityAutocompleteField> createState() =>
      _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState
    extends ConsumerState<CityAutocompleteField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<LocationResult> _offlineSuggestions = [];
  List<PlacePrediction> _googleSuggestions = [];
  Timer? _debounce;

  // Session token for Google Places — one per focus session
  String _sessionToken = '';
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Start a new session token when the field gains focus
      _sessionToken = _uuid.v4();
    } else {
      _removeOverlay();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (query.trim().length < 2) {
        _removeOverlay();
        return;
      }

      if (kDebugMode) {
        print('[CityAutocomplete] Query: "$query", useGooglePlaces: ${widget.useGooglePlaces}');
      }

      if (widget.useGooglePlaces && query.trim().length >= 3) {
        // ── GOOGLE-FIRST STRATEGY ──
        // 1. Try Google Places API first (precise addresses)
        final placesService = ref.read(googlePlacesServiceProvider);
        if (placesService.isAvailable) {
          if (kDebugMode) {
            print('[CityAutocomplete] Google-first: calling API...');
          }
          final googleResults = await placesService.searchPlaces(
            query,
            sessionToken: _sessionToken,
          );

          if (googleResults.isNotEmpty && mounted) {
            if (kDebugMode) {
              print('[CityAutocomplete] Google returned ${googleResults.length} results — showing Google-first');
            }
            setState(() {
              _googleSuggestions = googleResults;
              _offlineSuggestions = []; // Google has results, no need for offline
            });
            _showOverlay();
            return;
          }

          if (kDebugMode) {
            print('[CityAutocomplete] Google returned 0 results — falling back to offline');
          }
        }
      }

      // ── OFFLINE FALLBACK (or offline-only for Trucker) ──
      final offlineService = ref.read(citySearchServiceProvider);
      final offlineResults = await offlineService.search(query, limit: 8);

      if (kDebugMode) {
        print('[CityAutocomplete] Offline results: ${offlineResults.length}');
      }

      if (mounted) {
        setState(() {
          _offlineSuggestions = offlineResults;
          _googleSuggestions = [];
        });
        _showOverlay();
      }
    });
  }

  Future<void> _onGooglePredictionSelected(PlacePrediction prediction) async {
    final placesService = ref.read(googlePlacesServiceProvider);
    final details = await placesService.getPlaceDetails(
      prediction.placeId,
      sessionToken: _sessionToken,
    );

    // Generate a new session token for the next search
    _sessionToken = _uuid.v4();

    if (details != null) {
      widget.controller.text = details.name;
      widget.onCitySelected?.call(details);
    } else {
      // Fallback: use the prediction text as-is
      widget.controller.text = prediction.mainText;
      widget.onCitySelected?.call(LocationResult(
        name: prediction.mainText,
        state: '',
        address: prediction.description,
        locationType: LocationType.colony,
      ));
    }
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final query = widget.controller.text.trim();

    final googleCount = _googleSuggestions.length;
    final offlineCount = _offlineSuggestions.length;
    final showingGoogle = googleCount > 0;

    // Google mode: google results + footer
    // Offline mode: offline results + (exact address fallback?)
    final showExactAddress = !showingGoogle &&
        query.length >= 2 &&
        !_offlineSuggestions
            .any((s) => s.name.toLowerCase() == query.toLowerCase());

    final totalCount = showingGoogle
        ? googleCount + 1 // google results + "Powered by Google" footer
        : offlineCount + (showExactAddress ? 1 : 0);

    if (totalCount == 0) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.cardBg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: totalCount,
                itemBuilder: (context, index) {
                  if (showingGoogle) {
                    // ── Google results (primary) ──
                    if (index < googleCount) {
                      return _buildGoogleTile(_googleSuggestions[index]);
                    }
                    // Footer
                    return _buildGoogleFooter();
                  }

                  // ── Offline results (fallback or Trucker mode) ──
                  if (index < offlineCount) {
                    return _buildOfflineTile(_offlineSuggestions[index]);
                  }

                  // Exact address fallback
                  if (showExactAddress) {
                    return _buildExactAddressTile(query);
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOfflineTile(LocationResult loc) {
    return ListTile(
      dense: true,
      leading: Icon(
        loc.isMajorHub ? Icons.location_city : Icons.location_on_outlined,
        color: loc.isMajorHub ? AppColors.brandTeal : AppColors.textTertiary,
        size: 20,
      ),
      title: Text(
        loc.name,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: loc.isMajorHub ? FontWeight.w600 : FontWeight.normal,
          color: AppColors.textPrimary, // Ensure visible text color
        ),
      ),
      subtitle: Text(
        loc.district != null ? '${loc.district}, ${loc.state}' : loc.state,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary, // Better contrast
        ),
      ),
      onTap: () {
        widget.controller.text = loc.name;
        widget.onCitySelected?.call(loc);
        _removeOverlay();
        _focusNode.unfocus();
      },
    );
  }

  Widget _buildExactAddressTile(String query) {
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.edit_location_alt_outlined,
        color: AppColors.brandOrange,
        size: 20,
      ),
      title: Text(
        'Use exact address',
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.brandOrange,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '"$query"',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary, // Better contrast
        ),
      ),
      onTap: () {
        final loc = LocationResult(
          name: query,
          state: '',
          address: query,
          locationType: LocationType.colony,
        );
        widget.controller.text = query;
        widget.onCitySelected?.call(loc);
        _removeOverlay();
        _focusNode.unfocus();
      },
    );
  }

  Widget _buildGoogleTile(PlacePrediction prediction) {
    return ListTile(
      dense: true,
      leading: const Icon(
        Icons.place_outlined,
        color: AppColors.brandOrange,
        size: 20,
      ),
      title: Text(
        prediction.mainText,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary, // Ensure visible
        ),
      ),
      subtitle: Text(
        prediction.secondaryText,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary, // Better contrast
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _onGooglePredictionSelected(prediction),
    );
  }

  Widget _buildGoogleFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Powered by ',
            style: AppTypography.caption
                .copyWith(color: AppColors.textTertiary, fontSize: 9),
          ),
          Text(
            'Google',
            style: AppTypography.caption.copyWith(
              color: const Color(0xFF4285F4),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon)
              : null,
        ),
        textInputAction: widget.textInputAction ?? TextInputAction.next,
        onChanged: _onChanged,
        validator: widget.validator,
      ),
    );
  }
}
