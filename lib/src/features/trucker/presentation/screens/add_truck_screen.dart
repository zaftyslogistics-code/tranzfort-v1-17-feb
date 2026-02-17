import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';

class AddTruckScreen extends ConsumerStatefulWidget {
  const AddTruckScreen({super.key});

  @override
  ConsumerState<AddTruckScreen> createState() => _AddTruckScreenState();
}

class _AddTruckScreenState extends ConsumerState<AddTruckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _truckNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  String _bodyType = 'open';
  int _tyres = 6;
  bool _isLoading = false;
  File? _rcPhoto;

  static const _bodyTypes = ['open', 'container', 'trailer', 'tanker'];
  static const _tyreOptions = [6, 10, 12, 14, 16, 18, 22];

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final bodyType = await SmartDefaults.getLastBodyType();
    if (bodyType != null && _bodyTypes.contains(bodyType)) {
      setState(() => _bodyType = bodyType);
    }
  }

  @override
  void dispose() {
    _truckNumberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) return;

    if (_rcPhoto == null) {
      AppDialogs.showErrorSnackBar(context, 'RC photo is required for verification');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseServiceProvider);
      final userId = ref.read(authServiceProvider).currentUser!.id;
      final truckNumber = _truckNumberController.text.trim().toUpperCase();

      // Upload RC photo to storage
      // RLS requires auth.uid() as first folder segment
      final supabase = Supabase.instance.client;
      final fileExt = _rcPhoto!.path.split('.').last;
      final storagePath = '$userId/rc_$truckNumber.$fileExt';

      await supabase.storage.from('truck-images').upload(
        storagePath,
        _rcPhoto!,
        fileOptions: FileOptions(contentType: 'image/$fileExt'),
      );

      // Add truck with RC photo URL - status will be 'pending' by default per schema
      await db.addTruck({
        'owner_id': userId,
        'truck_number': truckNumber,
        'body_type': _bodyType,
        'tyres': _tyres,
        'capacity_tonnes': double.tryParse(_capacityController.text) ?? 0,
        'rc_photo_url': storagePath,
        'status': 'pending', // Explicitly set pending until admin review
      });

      SmartDefaults.saveLastBodyType(_bodyType);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(
            context, 'Truck added! Pending admin verification.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickRcPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _rcPhoto = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to pick image: $e');
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.brandTeal),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickRcPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.brandTeal),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickRcPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRcUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RC Book Photo', style: AppTypography.bodyMedium),
        const SizedBox(height: 8),
        Text(
          'Required for verification. Upload a clear photo of your RC book.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _rcPhoto != null ? AppColors.brandTeal : AppColors.borderDefault,
                width: _rcPhoto != null ? 2 : 1,
              ),
            ),
            child: _rcPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          _rcPhoto!,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _rcPhoto = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload RC photo',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Camera or Gallery',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Add Truck')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _truckNumberController,
                decoration: const InputDecoration(
                  labelText: 'Truck Number',
                  prefixIcon: Icon(Icons.local_shipping),
                  hintText: 'MH 12 AB 1234',
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Text('Body Type', style: AppTypography.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _bodyTypes.map((type) {
                  final selected = _bodyType == type;
                  return FilterChip(
                    label: Text(type[0].toUpperCase() + type.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _bodyType = type),
                    selectedColor: AppColors.brandTeal,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Number of Tyres', style: AppTypography.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _tyreOptions.map((tyre) {
                  final selected = _tyres == tyre;
                  return ChoiceChip(
                    label: Text('$tyre'),
                    selected: selected,
                    onSelected: (_) => setState(() => _tyres = tyre),
                    selectedColor: AppColors.brandTeal,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: 'Capacity (Tonnes)',
                  suffixText: 'tonnes',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              _buildRcUploadSection(),
              const SizedBox(height: 32),
              GradientButton(
                text: 'Add Truck',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleAdd,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
