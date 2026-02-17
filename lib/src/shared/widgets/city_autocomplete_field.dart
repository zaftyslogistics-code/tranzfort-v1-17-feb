import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/auth_service_provider.dart';
import '../../core/services/city_search_service.dart';

class CityAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon,
    this.textInputAction,
    this.validator,
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
  List<LocationResult> _suggestions = [];
  Timer? _debounce;

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
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length < 2) {
        _removeOverlay();
        return;
      }

      final service = ref.read(citySearchServiceProvider);
      final results = await service.search(query, limit: 8);

      if (mounted) {
        setState(() => _suggestions = results);
        if (results.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _showOverlay() {
    _removeOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

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
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final loc = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      loc.isMajorHub
                          ? Icons.location_city
                          : Icons.location_on_outlined,
                      color: loc.isMajorHub
                          ? AppColors.brandTeal
                          : AppColors.textTertiary,
                      size: 20,
                    ),
                    title: Text(
                      loc.name,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: loc.isMajorHub
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      loc.district != null
                          ? '${loc.district}, ${loc.state}'
                          : loc.state,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                    onTap: () {
                      widget.controller.text = loc.name;
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
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
