import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/services/schema_smoke_check_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _showSchemaErrorDialog(List<String> failures) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Service Temporarily Unavailable'),
        content: Text(
          'Required backend schema is not ready. Please contact support.\n\n'
          'Diagnostics:\n${failures.join('\n')}',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
              if (mounted) context.go('/login');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAuth() async {
    // Brief display for splash logo
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    final schemaCheck = SchemaSmokeCheckService(Supabase.instance.client);
    try {
      await schemaCheck.verifyUserRelations();
    } on SchemaSmokeCheckException catch (error) {
      if (!mounted) return;
      _showSchemaErrorDialog(error.failures);
      return;
    }

    // Ensure profile exists (handles phone OTP auto-signup)
    await authService.ensureProfileExists();

    // Check ban status
    final profile = await authService.getUserProfile();
    if (profile != null && profile['is_banned'] == true) {
      if (mounted) {
        _showBannedDialog(profile['ban_reason'] as String?);
      }
      return;
    }

    final role = await authService.getUserRole();

    if (!mounted) return;

    if (role == null || role.isEmpty) {
      context.go('/role-selection');
    } else if (role == 'supplier') {
      context.go('/supplier-dashboard');
    } else {
      context.go('/find-loads');
    }
  }

  void _showBannedDialog(String? reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Suspended'),
        content: Text(
          reason ?? 'Your account has been suspended. Please contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
              if (mounted) context.go('/login');
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: scale.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/images/splash-screen-logo.png',
            width: 220,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
