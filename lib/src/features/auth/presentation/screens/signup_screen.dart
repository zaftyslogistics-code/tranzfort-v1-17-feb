import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      AppDialogs.showSnackBar(context, 'Please agree to the Terms of Service and Privacy Policy');
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
        AppDialogs.showSuccessSnackBar(context, 'Account created! Please confirm your email, then log in.');
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
              Text('Create Account', style: AppTypography.h1Hero)
                  .staggerEntrance(1),
              const SizedBox(height: 4),
              Text(
                "Join India's trucking network",
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
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                ),
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().length < 2) {
                                    return 'Min 2 chars';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                ),
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().length < 2) {
                                    return 'Min 2 chars';
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
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
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
                            labelText: 'Password',
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
                            labelText: 'Confirm Password',
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
                              return 'Passwords do not match';
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
                              text: 'I agree to the ',
                              style: AppTypography.bodySmall,
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.brandTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
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
                          text: 'Create Account',
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
                      'Already have an account? ',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Login',
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
