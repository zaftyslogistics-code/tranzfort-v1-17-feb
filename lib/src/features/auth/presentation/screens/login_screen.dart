import 'package:flutter/material.dart';
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

enum _LoginMode { password, phoneOtp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  _LoginMode _loginMode = _LoginMode.password;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _mobileDigits {
    var digits = _identifierController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    return digits;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      var identifier = _identifierController.text.trim();

      // Auto-prepend +91 for mobile numbers
      if (!identifier.contains('@')) {
        identifier = identifier.replaceAll(' ', '');
      }

      await authService.signInWithPassword(
        identifier: identifier,
        password: _passwordController.text,
      );

      // Invalidate all providers to clear any stale data
      invalidateAllUserProviders(ref);

      // Ensure profile exists
      await authService.ensureProfileExists();

      // Fetch fresh role
      final role = await authService.getUserRole();

      if (!mounted) return;

      // Navigate explicitly based on role
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      if (role == null || role.isEmpty) {
        context.go('/role-selection');
      } else if (role == 'supplier') {
        context.go('/supplier-dashboard');
      } else {
        context.go('/find-loads');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOtpLogin() async {
    final mobile = _mobileDigits;
    if (mobile.isEmpty) {
      AppDialogs.showSnackBar(context, 'Enter your 10-digit mobile number');
      return;
    }

    final mobileValidation = Validators.indianMobile(mobile);
    if (mobileValidation != null) {
      AppDialogs.showSnackBar(
        context,
        'Please enter a valid 10-digit Indian mobile number',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithOtp(mobile: mobile);

      if (mounted) {
        context.push('/otp-verification', extra: '+91$mobile');
      }
    } on FormatException catch (e) {
      if (mounted) {
        AppDialogs.showSnackBar(context, e.message);
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
              const SizedBox(height: 48),
              // Logo
              Image.asset(
                'assets/images/main-logo-transparent.png',
                width: 160,
                fit: BoxFit.contain,
              ).staggerEntrance(0),
              const SizedBox(height: 24),
              Text('Welcome back', style: AppTypography.h1Hero)
                  .staggerEntrance(1),
              const SizedBox(height: 4),
              Text(
                'Sign in to continue',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ).staggerEntrance(2),
              const SizedBox(height: 32),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _loginMode = _LoginMode.password;
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      _loginMode == _LoginMode.password
                                          ? AppColors.brandTeal.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                  side: BorderSide(
                                    color: _loginMode == _LoginMode.password
                                        ? AppColors.brandTeal
                                        : AppColors.borderDefault,
                                  ),
                                ),
                                child: const Text('Password'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _loginMode = _LoginMode.phoneOtp;
                                        });
                                      },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      _loginMode == _LoginMode.phoneOtp
                                          ? AppColors.brandTeal.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                  side: BorderSide(
                                    color: _loginMode == _LoginMode.phoneOtp
                                        ? AppColors.brandTeal
                                        : AppColors.borderDefault,
                                  ),
                                ),
                                child: const Text('Login with Phone'),
                              ),
                            ),
                          ],
                        ).staggerEntrance(3),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _identifierController,
                          decoration: InputDecoration(
                            labelText: _loginMode == _LoginMode.phoneOtp
                                ? 'Mobile Number'
                                : 'Email or Mobile',
                            prefixIcon: Icon(
                              _loginMode == _LoginMode.phoneOtp
                                  ? Icons.phone_android_outlined
                                  : Icons.person_outline,
                            ),
                            prefixText: _loginMode == _LoginMode.phoneOtp
                                ? '+91 '
                                : null,
                          ),
                          keyboardType: _loginMode == _LoginMode.phoneOtp
                              ? TextInputType.phone
                              : TextInputType.emailAddress,
                          textInputAction: _loginMode == _LoginMode.phoneOtp
                              ? TextInputAction.done
                              : TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';

                            if (_loginMode == _LoginMode.phoneOtp) {
                              return Validators.indianMobile(_mobileDigits);
                            }

                            final trimmed = v.trim();
                            if (trimmed.contains('@')) {
                              return Validators.email(trimmed);
                            }
                            return Validators.indianMobile(
                                trimmed.replaceAll(RegExp(r'[\s\-\+]'), '').replaceFirst('91', ''));
                          },
                          onChanged: (_) => setState(() {}),
                        ).staggerEntrance(3),
                        if (_loginMode == _LoginMode.password) ...[
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
                            textInputAction: TextInputAction.done,
                            validator: Validators.password,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ).staggerEntrance(4),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        GradientButton(
                          text: _loginMode == _LoginMode.phoneOtp
                              ? 'Send OTP'
                              : 'Login',
                          isLoading: _isLoading,
                          onPressed: _isLoading
                              ? null
                              : (_loginMode == _LoginMode.phoneOtp
                                  ? _handleOtpLogin
                                  : _handleLogin),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom link
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/signup'),
                      child: Text(
                        'Sign Up',
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
