import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/city_autocomplete_field.dart';
import '../../providers/navigation_providers.dart';
import '../../services/saved_places_service.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  List<SavedPlace> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(savedPlacesServiceProvider);
      final places = await svc.getPlaces(userId);
      if (mounted) setState(() => _places = places);
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to load places: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPlace() async {
    final result = await showDialog<SavedPlace>(
      context: context,
      builder: (ctx) => const _SavedPlaceDialog(),
    );
    if (result == null) return;

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    try {
      final svc = ref.read(savedPlacesServiceProvider);
      await svc.addPlace(userId, result);
      await _loadPlaces();
      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Place saved!');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to save: $e');
      }
    }
  }

  Future<void> _editPlace(SavedPlace place) async {
    final result = await showDialog<SavedPlace>(
      context: context,
      builder: (ctx) => _SavedPlaceDialog(existing: place),
    );
    if (result == null || place.id == null) return;

    try {
      final svc = ref.read(savedPlacesServiceProvider);
      await svc.updatePlace(place.id!, {
        'label': result.label,
        'icon': result.icon,
        'city': result.city,
        if (result.state != null) 'state': result.state,
        if (result.lat != null) 'lat': result.lat,
        if (result.lng != null) 'lng': result.lng,
      });
      await _loadPlaces();
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to update: $e');
      }
    }
  }

  Future<void> _deletePlace(SavedPlace place) async {
    if (place.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Place'),
        content: Text('Delete "${place.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final svc = ref.read(savedPlacesServiceProvider);
      await svc.deletePlace(place.id!);
      await _loadPlaces();
      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Place deleted');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to delete: $e');
      }
    }
  }

  IconData _iconForType(String icon) {
    switch (icon) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.business;
      case 'depot':
        return Icons.warehouse;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Saved Places')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPlace,
        backgroundColor: AppColors.brandTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border,
                          size: 64, color: AppColors.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'No saved places yet',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your home, depot, or favorite stops',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPlaces,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                    itemCount: _places.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      return _buildPlaceCard(place);
                    },
                  ),
                ),
    );
  }

  Widget _buildPlaceCard(SavedPlace place) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.brandTealLight,
          child: Icon(_iconForType(place.icon),
              color: AppColors.brandTeal, size: 22),
        ),
        title: Text(
          place.label,
          style: AppTypography.bodyMedium
              .copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [place.city, if (place.state != null) place.state].join(', '),
          style:
              AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _editPlace(place);
            if (value == 'delete') _deletePlace(place);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit Dialog ──────────────────────────────────────────────────

class _SavedPlaceDialog extends StatefulWidget {
  final SavedPlace? existing;
  const _SavedPlaceDialog({this.existing});

  @override
  State<_SavedPlaceDialog> createState() => _SavedPlaceDialogState();
}

class _SavedPlaceDialogState extends State<_SavedPlaceDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _cityCtrl;
  String _icon = 'star';
  LatLng? _latLng;
  String? _state;

  @override
  void initState() {
    super.initState();
    _labelCtrl =
        TextEditingController(text: widget.existing?.label ?? '');
    _cityCtrl =
        TextEditingController(text: widget.existing?.city ?? '');
    _icon = widget.existing?.icon ?? 'star';
    if (widget.existing?.lat != null && widget.existing?.lng != null) {
      _latLng = LatLng(widget.existing!.lat!, widget.existing!.lng!);
    }
    _state = widget.existing?.state;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Place' : 'Add Place'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Home, Office, Depot',
              ),
            ),
            const SizedBox(height: 12),
            CityAutocompleteField(
              controller: _cityCtrl,
              labelText: 'City',
              prefixIcon: Icons.location_city,
              onCitySelected: (loc) {
                if (loc.hasCoordinates) {
                  _latLng = LatLng(loc.lat!, loc.lng!);
                }
                _state = loc.state;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Type:', style: AppTypography.caption),
                const SizedBox(width: 8),
                _iconChip('home', Icons.home, 'Home'),
                const SizedBox(width: 6),
                _iconChip('work', Icons.business, 'Work'),
                const SizedBox(width: 6),
                _iconChip('depot', Icons.warehouse, 'Depot'),
                const SizedBox(width: 6),
                _iconChip('star', Icons.star, 'Other'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            final city = _cityCtrl.text.trim();
            if (label.isEmpty || city.isEmpty) return;
            Navigator.pop(
              context,
              SavedPlace(
                label: label,
                icon: _icon,
                city: city,
                state: _state,
                lat: _latLng?.latitude,
                lng: _latLng?.longitude,
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandTeal,
          ),
          child: Text(isEdit ? 'Update' : 'Save'),
        ),
      ],
    );
  }

  Widget _iconChip(String value, IconData icon, String tooltip) {
    final selected = _icon == value;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _icon = value),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandTeal.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.brandTeal : AppColors.textTertiary,
            ),
          ),
          child: Icon(icon,
              size: 18,
              color: selected ? AppColors.brandTeal : AppColors.textTertiary),
        ),
      ),
    );
  }
}
