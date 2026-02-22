import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/animations.dart';
import '../../../../shared/widgets/gradient_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleCompleteRegistrationScreen extends ConsumerStatefulWidget {
  const GoogleCompleteRegistrationScreen({super.key});

  @override
  ConsumerState<GoogleCompleteRegistrationScreen> createState() =>
      _GoogleCompleteRegistrationScreenState();
}

class _GoogleCompleteRegistrationScreenState
    extends ConsumerState<GoogleCompleteRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _consentChecked = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteRegistration() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      AppDialogs.showSnackBar(
          context, '${l10n.agreeTo} ${l10n.termsOfService} & ${l10n.privacyPolicy}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      
      if (user == null) {
        throw Exception('User session lost. Please try logging in again.');
      }

      final mobile = '+91${_mobileController.text.trim()}';

      // Update auth user metadata with phone number
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'mobile': mobile},
        ),
      );

      // We explicitly create the profile here since we have all the info now
      final fullName = user.userMetadata?['full_name'] as String? ?? 
                       user.userMetadata?['name'] as String? ?? '';
      final email = user.email ?? '';

      // Create/Update profile record
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName.isNotEmpty ? fullName : email.split('@').first,
        'email': email,
        'mobile': mobile,
      }, onConflict: 'id');

      // Record consent
      final db = ref.read(databaseServiceProvider);
      await db.recordConsent(
        profileId: user.id,
        consentType: 'terms_and_privacy',
        consentVersion: '1.0',
      );

      // Invalidate providers
      invalidateAllUserProviders(ref);

      if (!mounted) return;

      // Navigate to role selection since this is a new registration
      context.go('/role-selection');

    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(authServiceProvider).currentUser;
    final email = user?.email ?? '';
    final name = user?.userMetadata?['full_name'] as String? ?? 
                 user?.userMetadata?['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
          ),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Image.asset(
                'assets/images/main-logo-transparent.png',
                width: 120,
                fit: BoxFit.contain,
              ).staggerEntrance(0),
              const SizedBox(height: 16),
              Text('Almost Done!', style: AppTypography.h1Hero)
                  .staggerEntrance(1),
              const SizedBox(height: 8),
              Text(
                'Please provide your mobile number to complete registration',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ).staggerEntrance(2),
              const SizedBox(height: 32),
              
              // Google Info Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: user?.userMetadata?['avatar_url'] != null 
                          ? NetworkImage(user!.userMetadata!['avatar_url'])
                          : null,
                      child: user?.userMetadata?['avatar_url'] == null 
                          ? const Icon(Icons.person, color: AppColors.brandTeal)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            email,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).staggerEntrance(3),

              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: l10n.mobile,
                            helperText: 'Only Indian mobile numbers are allowed',
                            prefixIcon: Container(
                              width: 60,
                              alignment: Alignment.center,
                              child: Text(
                                '+91',
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandTeal,
                                ),
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.done,
                          validator: Validators.indianMobile,
                        ).staggerEntrance(4),
                        const SizedBox(height: 16),
                        
                        // Privacy consent
                        CheckboxListTile(
                          value: _consentChecked,
                          onChanged: (v) =>
                              setState(() => _consentChecked = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text.rich(
                            TextSpan(
                              text: '${l10n.agreeTo} ',
                              style: AppTypography.bodySmall,
                              children: [
                                TextSpan(
                                  text: l10n.termsOfService,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.brandTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: ' ${l10n.and} '),
                                TextSpan(
                                  text: l10n.privacyPolicy,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.brandTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          activeColor: AppColors.brandTeal,
                        ).staggerEntrance(5),
                        const SizedBox(height: 24),
                        GradientButton(
                          text: 'Complete Registration',
                          isLoading: _isLoading,
                          onPressed: (!_consentChecked || _isLoading)
                              ? null
                              : _handleCompleteRegistration,
                        ).staggerEntrance(6),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () async {
                            final goRouter = GoRouter.of(context);
                            await ref.read(authServiceProvider).signOut();
                            if (mounted) goRouter.go('/login');
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ).staggerEntrance(7),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
