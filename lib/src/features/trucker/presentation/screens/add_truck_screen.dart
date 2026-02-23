import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/models/truck_model_spec.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';

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
  File? _truckPhoto; // TRUCK-IMG1: Truck image saved locally

  // V4-1: Master truck model selection
  List<String> _makes = [];
  List<TruckModelSpec> _modelsForMake = [];
  String? _selectedMake;
  TruckModelSpec? _selectedSpec;
  bool _isManualEntry = false;
  bool _loadingModels = true;

  static const _bodyTypes = ['open', 'container', 'trailer', 'tanker'];
  static const _tyreOptions = [6, 10, 12, 14, 16, 18, 22];

  @override
  void initState() {
    super.initState();
    _loadDefaults();
    _loadTruckMakes();
  }

  Future<void> _loadDefaults() async {
    final bodyType = await SmartDefaults.getLastBodyType();
    if (bodyType != null && _bodyTypes.contains(bodyType)) {
      setState(() => _bodyType = bodyType);
    }
  }

  Future<void> _loadTruckMakes() async {
    try {
      final svc = ref.read(truckModelServiceProvider);
      final makes = await svc.getMakes();
      if (mounted) setState(() { _makes = makes; _loadingModels = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _onMakeSelected(String? make) async {
    if (make == null) return;
    setState(() { _selectedMake = make; _selectedSpec = null; _modelsForMake = []; });
    final svc = ref.read(truckModelServiceProvider);
    final models = await svc.getModelsForMake(make);
    if (mounted) setState(() => _modelsForMake = models);
  }

  void _onModelSelected(TruckModelSpec? spec) {
    if (spec == null) return;
    setState(() {
      _selectedSpec = spec;
      _bodyType = spec.bodyType;
      _tyres = spec.tyres;
      _capacityController.text = (spec.payloadKg / 1000).toStringAsFixed(1);
    });
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
      AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.requiredField);
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

      // TRUCK-IMG1: Save truck photo locally if provided
      String? localTruckPhotoPath;
      if (_truckPhoto != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final truckImgDir = Directory('${appDir.path}/truck_photos');
          if (!await truckImgDir.exists()) {
            await truckImgDir.create(recursive: true);
          }
          final ext = _truckPhoto!.path.split('.').last;
          final destPath = '${truckImgDir.path}/${truckNumber}_${DateTime.now().millisecondsSinceEpoch}.$ext';
          await _truckPhoto!.copy(destPath);
          localTruckPhotoPath = destPath;
        } catch (_) {
          // Non-critical — truck photo is optional
        }
      }

      // Add truck with RC photo URL - status will be 'pending' by default per schema
      await db.addTruck({
        'owner_id': userId,
        'truck_number': truckNumber,
        'body_type': _bodyType,
        'tyres': _tyres,
        'capacity_tonnes': double.tryParse(_capacityController.text) ?? 0,
        'rc_photo_url': storagePath,
        'status': 'pending', // Explicitly set pending until admin review
        if (_selectedSpec != null) 'truck_model_id': _selectedSpec!.id,
      });

      // TRUCK-IMG1: Save truck photo path locally (not in DB — column doesn't exist)
      if (localTruckPhotoPath != null) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'truck_photo_$truckNumber';
        await prefs.setString(key, localTruckPhotoPath);
      }

      SmartDefaults.saveLastBodyType(_bodyType);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(
            context, AppLocalizations.of(context)!.pending);
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
        maxWidth: 1200,
        maxHeight: 1200,
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
                title: Text(AppLocalizations.of(context)!.upload),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickRcPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.brandTeal),
                title: Text(AppLocalizations.of(context)!.upload),
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

  Future<void> _pickTruckPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _truckPhoto = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to pick image: $e');
      }
    }
  }

  Widget _buildTruckPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Truck Photo', style: AppTypography.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Optional — add a photo of your truck to share with suppliers',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
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
                        title: const Text('Camera'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickTruckPhoto(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library, color: AppColors.brandTeal),
                        title: const Text('Gallery'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickTruckPhoto(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _truckPhoto != null ? AppColors.brandTeal : AppColors.borderDefault,
                width: _truckPhoto != null ? 2 : 1,
              ),
            ),
            child: _truckPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_truckPhoto!, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _truckPhoto = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Add Truck Photo',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text('Camera or Gallery',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRcUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.upload, style: AppTypography.bodyMedium),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.requiredField,
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
                        AppLocalizations.of(context)!.upload,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.upload,
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

  Widget _buildMakeModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Truck Make & Model', style: AppTypography.bodyMedium),
            const Spacer(),
            if (!_loadingModels)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isManualEntry = !_isManualEntry;
                    if (_isManualEntry) {
                      _selectedMake = null;
                      _selectedSpec = null;
                      _modelsForMake = [];
                    }
                  });
                },
                child: Text(
                  _isManualEntry ? 'Select from list' : 'Enter manually',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.brandTeal),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingModels)
          const Center(child: Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ))
        else if (!_isManualEntry) ...[
          // Make dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedMake,
            decoration: const InputDecoration(
              labelText: 'Make (Company)',
              prefixIcon: Icon(Icons.factory_outlined),
            ),
            items: _makes.map((make) => DropdownMenuItem(
              value: make,
              child: Text(make),
            )).toList(),
            onChanged: _onMakeSelected,
          ),
          const SizedBox(height: 12),
          // Model dropdown (enabled only after make is selected)
          DropdownButtonFormField<TruckModelSpec>(
            initialValue: _selectedSpec,
            decoration: InputDecoration(
              labelText: 'Model',
              prefixIcon: const Icon(Icons.local_shipping_outlined),
              hintText: _selectedMake == null ? 'Select make first' : 'Select model',
            ),
            items: _modelsForMake.map((spec) => DropdownMenuItem(
              value: spec,
              child: Text(spec.model),
            )).toList(),
            onChanged: _selectedMake == null ? null : _onModelSelected,
          ),
        ],
      ],
    );
  }

  Widget _buildSpecCard() {
    final spec = _selectedSpec!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.brandTeal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.displayName,
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedSpec = null;
                  _selectedMake = null;
                  _modelsForMake = [];
                }),
                child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _specChip('Body', spec.bodyType[0].toUpperCase() + spec.bodyType.substring(1)),
              _specChip('Axles', '${spec.axles}'),
              _specChip('Tyres', '${spec.tyres}'),
              _specChip('GVW', '${(spec.gvwKg / 1000).toStringAsFixed(0)}T'),
              _specChip('Payload', '${(spec.payloadKg / 1000).toStringAsFixed(0)}T'),
              if (spec.heightM != null) _specChip('Height', '${spec.heightM!.toStringAsFixed(1)}m'),
              if (spec.mileageLoadedKmpl != null)
                _specChip('Mileage', '${spec.mileageLoadedKmpl!.toStringAsFixed(1)} km/L'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.addTruck),
        actions: [
          TtsButton(
            text: 'Read aloud',
            spokenText: ref.watch(localeProvider).languageCode == 'hi'
                ? 'ट्रक जोड़ें। ट्रक नंबर, कैपेसिटी, बॉडी टाइप, टायर और RC फोटो अपलोड करें।'
                : 'Add truck. Enter truck number, capacity, body type, tyres, and upload RC photo.',
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
        ],
      ),
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.truckType,
                  prefixIcon: const Icon(Icons.local_shipping),
                  hintText: 'MH 12 AB 1234',
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.requiredField : null,
              ),
              const SizedBox(height: 20),

              // V4-1: Make/Model selection
              _buildMakeModelSection(),
              const SizedBox(height: 16),

              // Auto-filled spec card (shown when model is selected)
              if (_selectedSpec != null) _buildSpecCard(),
              if (_selectedSpec != null) const SizedBox(height: 16),

              // Manual entry toggle or fields
              if (_isManualEntry || _selectedSpec == null) ...[
                Text(AppLocalizations.of(context)!.truckType, style: AppTypography.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _bodyTypes.map((type) {
                    final selected = _bodyType == type;
                    return FilterChip(
                      label: Text(type[0].toUpperCase() + type.substring(1)),
                      selected: selected,
                      onSelected: _selectedSpec != null ? null : (_) => setState(() => _bodyType = type),
                      selectedColor: AppColors.brandTeal,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.tyres, style: AppTypography.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _tyreOptions.map((tyre) {
                    final selected = _tyres == tyre;
                    return ChoiceChip(
                      label: Text('$tyre'),
                      selected: selected,
                      onSelected: _selectedSpec != null ? null : (_) => setState(() => _tyres = tyre),
                      selectedColor: AppColors.brandTeal,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _capacityController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.of(context)!.weight} (${AppLocalizations.of(context)!.tonnes})',
                  suffixText: AppLocalizations.of(context)!.tonnes,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                readOnly: _selectedSpec != null,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? AppLocalizations.of(context)!.requiredField : null,
              ),
              const SizedBox(height: 24),
              _buildTruckPhotoSection(),
              const SizedBox(height: 24),
              _buildRcUploadSection(),
              const SizedBox(height: 32),
              GradientButton(
                text: AppLocalizations.of(context)!.addTruck,
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
