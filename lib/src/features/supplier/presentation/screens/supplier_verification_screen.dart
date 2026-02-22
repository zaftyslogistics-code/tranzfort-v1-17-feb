import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';

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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppLocalizations.of(ctx)!.camera),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.of(ctx)!.gallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
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

  bool get _isResubmission {
    final status = ref.read(userProfileProvider).valueOrNull?['verification_status'] as String?;
    return status == 'rejected';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // For first-time submissions, all required docs must be selected.
    // For re-submissions (rejected), only newly selected docs are re-uploaded;
    // previously uploaded docs are kept as-is.
    if (!_isResubmission) {
      if (_aadhaarFrontPhoto == null || _aadhaarBackPhoto == null) {
        AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.requiredField);
        return;
      }
      if (_panPhoto == null) {
        AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.requiredField);
        return;
      }
      if (_businessLicencePhoto == null) {
        AppDialogs.showErrorSnackBar(context, AppLocalizations.of(context)!.requiredField);
        return;
      }
    } else {
      // Re-submission: at least one new doc or text change is expected
      final hasNewDoc = _aadhaarFrontPhoto != null ||
          _aadhaarBackPhoto != null ||
          _panPhoto != null ||
          _businessLicencePhoto != null ||
          _gstCertificatePhoto != null;
      if (!hasNewDoc) {
        AppDialogs.showSnackBar(context, 'Please re-upload at least the rejected document.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final db = ref.read(databaseServiceProvider);
      final userId = authService.currentUser!.id;
      final supabase = Supabase.instance.client;

      // Upload only newly selected documents
      final String aadhaarFrontPath = '$userId/aadhaar_front.jpg';
      final String aadhaarBackPath = '$userId/aadhaar_back.jpg';
      final String panPath = '$userId/pan.jpg';

      if (_aadhaarFrontPhoto != null) {
        await supabase.storage.from('verification-docs').upload(
          aadhaarFrontPath,
          _aadhaarFrontPhoto!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      }
      if (_aadhaarBackPhoto != null) {
        await supabase.storage.from('verification-docs').upload(
          aadhaarBackPath,
          _aadhaarBackPhoto!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      }
      if (_panPhoto != null) {
        await supabase.storage.from('verification-docs').upload(
          panPath,
          _panPhoto!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      }

      // Business licence — only upload if newly selected
      final String businessLicencePath = '$userId/business_licence.jpg';
      if (_businessLicencePhoto != null) {
        await supabase.storage.from('verification-docs').upload(
          businessLicencePath,
          _businessLicencePhoto!,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
      }

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

      // Update profile — only include doc paths that were newly uploaded
      final profileUpdate = <String, dynamic>{
        'aadhaar_last4': _aadhaarController.text.trim(),
        'pan_number': _panController.text.trim().toUpperCase(),
        'verification_status': 'pending',
      };
      if (_aadhaarFrontPhoto != null) {
        profileUpdate['aadhaar_front_photo_url'] = aadhaarFrontPath;
      }
      if (_aadhaarBackPhoto != null) {
        profileUpdate['aadhaar_back_photo_url'] = aadhaarBackPath;
      }
      if (_panPhoto != null) {
        profileUpdate['pan_photo_url'] = panPath;
      }
      await db.updateProfile(userId, profileUpdate);

      // Update supplier data
      final supplierUpdateData = <String, dynamic>{
        'company_name': _companyNameController.text.trim(),
        'gst_number': _gstController.text.trim().toUpperCase(),
      };
      if (_businessLicencePhoto != null) {
        supplierUpdateData['business_licence_doc_url'] = businessLicencePath;
      }
      if (gstCertificatePath != null) {
        supplierUpdateData['gst_photo_url'] = gstCertificatePath;
      }
      await db.updateSupplierData(userId, supplierUpdateData);

      ref.invalidate(userProfileProvider);
      ref.invalidate(supplierDataProvider);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(
          context, AppLocalizations.of(context)!.pending);
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: isUploaded
                    ? Image.file(photo, fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.brandTealLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: AppColors.brandTeal),
                      ),
              ),
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
              const Icon(Icons.add_a_photo, color: AppColors.textSecondary),
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
        title: Text(AppLocalizations.of(context)!.verification),
        actions: [
          TtsButton(
            text: 'Read aloud',
            spokenText: ref.watch(localeProvider).languageCode == 'hi'
                ? 'अकाउंट वेरिफिकेशन। आधार, PAN कार्ड और बिज़नेस दस्तावेज़ अपलोड करें। 24 घंटे में समीक्षा होगी।'
                : 'Account Verification. Upload your Aadhaar, PAN card, and business documents. We will review within 24 hours.',
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
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

            Text(AppLocalizations.of(context)!.verification, style: AppTypography.h3Subsection),
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

            Text(AppLocalizations.of(context)!.verification, style: AppTypography.h3Subsection),
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
            Text(AppLocalizations.of(context)!.upload, style: AppTypography.h3Subsection),
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
                  ? AppLocalizations.of(context)!.submit
                  : AppLocalizations.of(context)!.submit,
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
