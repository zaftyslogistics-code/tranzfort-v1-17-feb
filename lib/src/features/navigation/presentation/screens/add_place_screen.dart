import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../providers/navigation_providers.dart';
import '../../services/location_suggestions_service.dart';

class AddPlaceScreen extends ConsumerStatefulWidget {
  /// Pre-fill lat/lng if launched from map long-press
  final double? initialLat;
  final double? initialLng;

  const AddPlaceScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  PoiCategory _selectedCategory = PoiCategory.dhaba;
  double? _lat;
  double? _lng;
  String? _district;
  String? _state;

  bool _isLocating = false;
  bool _isSubmitting = false;
  final List<File> _photos = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _lat = widget.initialLat;
      _lng = widget.initialLng;
    } else {
      _autoLocate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _autoLocate() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= 3) {
      AppDialogs.showErrorSnackBar(context, 'Maximum 3 photos allowed');
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 960,
        imageQuality: 75,
      );
      if (picked != null && mounted) {
        setState(() => _photos.add(File(picked.path)));
      }
    } catch (e) {
      if (mounted) AppDialogs.showErrorSnackBar(context, 'Could not pick photo');
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _uploadPhotos(String userId) async {
    final supabase = Supabase.instance.client;
    final urls = <String>[];
    for (final file in _photos) {
      try {
        final ext = file.path.split('.').last.toLowerCase();
        final path = 'location_suggestions/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage.from('media').upload(path, file);
        final url = supabase.storage.from('media').getPublicUrl(path);
        urls.add(url);
      } catch (_) {
        // Skip failed uploads silently — photos are optional
      }
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      AppDialogs.showErrorSnackBar(
          context, 'Please set a location using the GPS button');
      return;
    }

    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) {
      AppDialogs.showErrorSnackBar(context, 'Please log in to submit a place');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final photoUrls = await _uploadPhotos(userId);

      final suggestion = LocationSuggestion(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        lat: _lat!,
        lng: _lng!,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        pincode: _pincodeController.text.trim().isEmpty
            ? null
            : _pincodeController.text.trim(),
        district: _district,
        state: _state,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        photos: photoUrls,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final svc = ref.read(locationSuggestionsServiceProvider);
      await svc.submit(userId, suggestion);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(
          context,
          'Place submitted! It will appear after review.',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to submit: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Add a Place', style: AppTypography.h3Subsection),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── GPS Location Card ──
            _buildLocationCard(),
            const SizedBox(height: AppSpacing.md),

            // ── Category ──
            _buildSectionLabel('Category *'),
            const SizedBox(height: AppSpacing.xs),
            _buildCategoryGrid(),
            const SizedBox(height: AppSpacing.md),

            // ── Name ──
            _buildSectionLabel('Place Name *'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Sharma Dhaba, MIDC Gate 3',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Address ──
            _buildSectionLabel('Address / Landmark'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                hintText: 'e.g. NH44, near Nagpur toll, opp. petrol pump',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Pincode + Phone row ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Pincode'),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _pincodeController,
                        decoration: const InputDecoration(
                          hintText: '400001',
                          prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length != 6) {
                            return '6 digits';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('Phone'),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          hintText: '9876543210',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Notes ──
            _buildSectionLabel('Notes (optional)'),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'e.g. Open 24x7, good parking, diesel available',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Photos ──
            _buildSectionLabel('Photos (optional, max 3)'),
            const SizedBox(height: AppSpacing.xs),
            _buildPhotoRow(),
            const SizedBox(height: AppSpacing.xl),

            // ── Submit ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit for Review',
                  style: AppTypography.buttonLarge,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'Your submission will be reviewed before going live.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: _lat != null ? AppColors.brandTeal : AppColors.borderDefault,
          width: _lat != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _lat != null
                  ? AppColors.brandTealLight
                  : AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _lat != null
                  ? Icons.location_on
                  : Icons.location_searching,
              color: _lat != null
                  ? AppColors.brandTeal
                  : AppColors.textTertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lat != null ? 'Location set' : 'Location not set',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _lat != null
                        ? AppColors.brandTeal
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _lat != null
                      ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                      : 'Tap to use your current GPS location',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _isLocating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: Icon(
                    Icons.my_location_outlined,
                    color: AppColors.brandTeal,
                  ),
                  tooltip: 'Use current location',
                  onPressed: _autoLocate,
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: PoiCategory.values.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandTeal : AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.brandTeal
                    : AppColors.borderDefault,
              ),
              boxShadow: selected ? AppColors.cardShadow : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconForCategory(cat),
                  size: 14,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  cat.label,
                  style: AppTypography.caption.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoRow() {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add photo button
          if (_photos.length < 3)
            GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.borderDefault, style: BorderStyle.solid),
                ),
                child: const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          // Existing photos
          ..._photos.asMap().entries.map((entry) {
            final i = entry.key;
            final file = entry.value;
            return Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: FileImage(file),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  static IconData _iconForCategory(PoiCategory cat) {
    switch (cat) {
      case PoiCategory.dhaba:
        return Icons.restaurant_outlined;
      case PoiCategory.fuelStation:
        return Icons.local_gas_station_outlined;
      case PoiCategory.loadingPoint:
        return Icons.upload_outlined;
      case PoiCategory.unloadingPoint:
        return Icons.download_outlined;
      case PoiCategory.truckParking:
        return Icons.local_parking_outlined;
      case PoiCategory.warehouse:
        return Icons.warehouse_outlined;
      case PoiCategory.factory:
        return Icons.factory_outlined;
      case PoiCategory.tyreShop:
        return Icons.tire_repair_outlined;
      case PoiCategory.mechanic:
        return Icons.build_outlined;
      case PoiCategory.restArea:
        return Icons.hotel_outlined;
      case PoiCategory.transportNagar:
        return Icons.local_shipping_outlined;
      case PoiCategory.other:
        return Icons.place_outlined;
    }
  }
}
