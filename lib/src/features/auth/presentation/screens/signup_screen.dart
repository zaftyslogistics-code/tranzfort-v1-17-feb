import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/animations.dart';
import '../../../../shared/widgets/gradient_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _consentChecked = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      AppDialogs.showSnackBar(context, '${l10n.termsOfService} ${l10n.privacyPolicy} ${l10n.agreeRequired}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final mobile = '+91${_mobileController.text.trim()}';

      await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: fullName,
        mobile: mobile,
      );

      // Record consent
      final user = authService.currentUser;
      if (user != null) {
        final db = ref.read(databaseServiceProvider);
        await db.recordConsent(
          profileId: user.id,
          consentType: 'terms_and_privacy',
          consentVersion: '1.0',
        );
      }

      // Keep signup flow deterministic when email confirmation is enabled.
      // Some Supabase setups may return a temporary session on sign-up.
      // We explicitly sign out so the user must log in after verification.
      await authService.signOut();
      invalidateAllUserProviders(ref);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, l10n.accountCreatedSuccess);
        context.go('/login');
      }
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
              Text(l10n.createAccount, style: AppTypography.h1Hero)
                  .staggerEntrance(1),
              const SizedBox(height: 4),
              Text(
                l10n.joinNetwork,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ).staggerEntrance(2),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // First + Last Name
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                decoration: InputDecoration(
                                  labelText: l10n.firstName,
                                ),
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().length < 2) {
                                    return l10n.minLengthRequired;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText: l10n.lastName,
                                ),
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().length < 2) {
                                    return l10n.minLengthRequired;
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: l10n.email,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: l10n.mobile,
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
                          textInputAction: TextInputAction.next,
                          validator: Validators.indianMobile,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: l10n.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: l10n.confirmPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return l10n.passwordsDontMatch;
                            }
                            return null;
                          },
                        ),
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
                        ),
                        const SizedBox(height: 16),
                        GradientButton(
                          text: l10n.createAccount,
                          isLoading: _isLoading,
                          onPressed: (!_consentChecked || _isLoading)
                              ? null
                              : _handleSignup,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${l10n.alreadyHaveAccount} ',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        l10n.login,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.brandTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
