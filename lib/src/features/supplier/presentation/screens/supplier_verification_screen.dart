import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/status_chip.dart';

class SupplierVerificationScreen extends ConsumerStatefulWidget {
  const SupplierVerificationScreen({super.key});

  @override
  ConsumerState<SupplierVerificationScreen> createState() =>
      _SupplierVerificationScreenState();
}

class _SupplierVerificationScreenState
    extends ConsumerState<SupplierVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _gstController = TextEditingController();
  bool _isLoading = false;

  // Document files
  File? _aadhaarFrontPhoto;
  File? _aadhaarBackPhoto;
  File? _panPhoto;
  File? _businessLicencePhoto;
  File? _gstCertificatePhoto;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final supplier = ref.read(supplierDataProvider).valueOrNull;

    if (profile != null) {
      _aadhaarController.text = profile['aadhaar_last4'] as String? ?? '';
      _panController.text = profile['pan_number'] as String? ?? '';
    }
    if (supplier != null) {
      _companyNameController.text = supplier['company_name'] as String? ?? '';
      _gstController.text = supplier['gst_number'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _panController.dispose();
    _companyNameController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<File?> _pickDocumentPhoto(String documentName) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked != null) {
        return File(picked.path);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, 'Failed to capture $documentName: $e');
      }
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required documents
    if (_aadhaarFrontPhoto == null || _aadhaarBackPhoto == null) {
      AppDialogs.showErrorSnackBar(context, 'Aadhaar front and back photos are required');
      return;
    }
    if (_panPhoto == null) {
      AppDialogs.showErrorSnackBar(context, 'PAN photo is required');
      return;
    }
    if (_businessLicencePhoto == null) {
      AppDialogs.showErrorSnackBar(context, 'Business licence photo is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final db = ref.read(databaseServiceProvider);
      final userId = authService.currentUser!.id;
      final supabase = Supabase.instance.client;

      // Upload documents to storage
      final String aadhaarFrontPath = '$userId/aadhaar_front.jpg';
      final String aadhaarBackPath = '$userId/aadhaar_back.jpg';
      final String panPath = '$userId/pan.jpg';

      await supabase.storage.from('verification-docs').upload(
        aadhaarFrontPath,
        _aadhaarFrontPhoto!,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      await supabase.storage.from('verification-docs').upload(
        aadhaarBackPath,
        _aadhaarBackPhoto!,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      await supabase.storage.from('verification-docs').upload(
        panPath,
        _panPhoto!,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      // Required: Business licence
      final String businessLicencePath = '$userId/business_licence.jpg';
      await supabase.storage.from('verification-docs').upload(
        businessLicencePath,
        _businessLicencePhoto!,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );

      // Optional: GST certificate image
      String? gstCertificatePath;
      if (_gstCertificatePhoto != null) {
        gstCertificatePath = '$userId/gst_certificate.jpg';
        await supabase.storage.from('verification-docs').upload(
          gstCertificatePath,
          _gstCertificatePhoto!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      }

      // Update profile with document paths
      await db.updateProfile(userId, {
        'aadhaar_last4': _aadhaarController.text.trim(),
        'pan_number': _panController.text.trim().toUpperCase(),
        'verification_status': 'pending',
        'aadhaar_front_photo_url': aadhaarFrontPath,
        'aadhaar_back_photo_url': aadhaarBackPath,
        'pan_photo_url': panPath,
      });

      // Update supplier data
      final supplierUpdateData = <String, dynamic>{
        'company_name': _companyNameController.text.trim(),
        'gst_number': _gstController.text.trim().toUpperCase(),
        'business_licence_doc_url': businessLicencePath,
      };
      if (gstCertificatePath != null) {
        supplierUpdateData['gst_photo_url'] = gstCertificatePath;
      }
      await db.updateSupplierData(userId, supplierUpdateData);

      ref.invalidate(userProfileProvider);
      ref.invalidate(supplierDataProvider);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(
          context, 'Verification submitted! We\'ll review within 24 hours.');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required IconData icon,
    required File? photo,
    required VoidCallback onTap,
    required VoidCallback onClear,
    bool isOptional = false,
  }) {
    final isUploaded = photo != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUploaded ? AppColors.successLight : AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUploaded ? AppColors.success : AppColors.borderDefault,
            width: isUploaded ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isUploaded
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.brandTealLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isUploaded
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : Icon(icon, color: AppColors.brandTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isUploaded ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    isUploaded ? 'Uploaded ✓' : (isOptional ? 'Tap to capture (Optional)' : 'Tap to capture (Required)'),
                    style: AppTypography.bodySmall.copyWith(
                      color: isUploaded ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isUploaded)
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              )
            else
              const Icon(Icons.camera_alt, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final verificationStatus =
        profileAsync.valueOrNull?['verification_status'] as String? ??
            'unverified';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Verification'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusChip(status: verificationStatus),
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
            if (verificationStatus == 'rejected')
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profileAsync.valueOrNull?['verification_rejection_reason']
                          as String? ??
                      'Verification was rejected. Please re-submit.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                ),
              ),

            Text('Company Details', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                prefixIcon: Icon(Icons.business),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, 'Company name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gstController,
              decoration: const InputDecoration(
                labelText: 'GST Number',
                prefixIcon: Icon(Icons.receipt_long),
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            Text('Personal Documents', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aadhaarController,
              decoration: const InputDecoration(
                labelText: 'Aadhaar (Last 4 digits)',
                prefixIcon: Icon(Icons.badge),
                hintText: '1234',
              ),
              maxLength: 4,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: Validators.aadhaarLast4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _panController,
              decoration: const InputDecoration(
                labelText: 'PAN Number',
                prefixIcon: Icon(Icons.credit_card),
                hintText: 'ABCDE1234F',
              ),
              maxLength: 10,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              validator: Validators.pan,
            ),
            const SizedBox(height: 24),
            Text('Document Photos (Required)', style: AppTypography.h3Subsection),
            const SizedBox(height: 8),
            Text(
              'Take clear photos of your documents. All information must be clearly visible.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildDocumentUploadCard(
              title: 'Aadhaar Front',
              icon: Icons.badge_outlined,
              photo: _aadhaarFrontPhoto,
              onTap: () async {
                final photo = await _pickDocumentPhoto('Aadhaar Front');
                if (photo != null) setState(() => _aadhaarFrontPhoto = photo);
              },
              onClear: () => setState(() => _aadhaarFrontPhoto = null),
            ),
            const SizedBox(height: 12),
            _buildDocumentUploadCard(
              title: 'Aadhaar Back',
              icon: Icons.badge_outlined,
              photo: _aadhaarBackPhoto,
              onTap: () async {
                final photo = await _pickDocumentPhoto('Aadhaar Back');
                if (photo != null) setState(() => _aadhaarBackPhoto = photo);
              },
              onClear: () => setState(() => _aadhaarBackPhoto = null),
            ),
            const SizedBox(height: 12),
            _buildDocumentUploadCard(
              title: 'PAN Card',
              icon: Icons.credit_card_outlined,
              photo: _panPhoto,
              onTap: () async {
                final photo = await _pickDocumentPhoto('PAN Card');
                if (photo != null) setState(() => _panPhoto = photo);
              },
              onClear: () => setState(() => _panPhoto = null),
            ),
            const SizedBox(height: 12),
            _buildDocumentUploadCard(
              title: 'Business Licence',
              icon: Icons.business_outlined,
              photo: _businessLicencePhoto,
              onTap: () async {
                final photo = await _pickDocumentPhoto('Business Licence');
                if (photo != null) setState(() => _businessLicencePhoto = photo);
              },
              onClear: () => setState(() => _businessLicencePhoto = null),
            ),
            const SizedBox(height: 12),
            _buildDocumentUploadCard(
              title: 'GST Certificate (Optional)',
              icon: Icons.receipt_long_outlined,
              photo: _gstCertificatePhoto,
              onTap: () async {
                final photo = await _pickDocumentPhoto('GST Certificate');
                if (photo != null) setState(() => _gstCertificatePhoto = photo);
              },
              onClear: () => setState(() => _gstCertificatePhoto = null),
              isOptional: true,
            ),
            const SizedBox(height: 24),

            GradientButton(
              text: verificationStatus == 'pending'
                  ? 'Resubmit Verification'
                  : 'Submit Verification',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleSubmit,
            ),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }
}
