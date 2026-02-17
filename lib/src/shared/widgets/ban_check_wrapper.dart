import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_service_provider.dart';

/// Wraps the app to check ban status on app resume (foreground return).
/// If the user is banned, shows a dialog and signs them out.
class BanCheckWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const BanCheckWrapper({super.key, required this.child});

  @override
  ConsumerState<BanCheckWrapper> createState() => _BanCheckWrapperState();
}

class _BanCheckWrapperState extends ConsumerState<BanCheckWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBanStatus();
    }
  }

  Future<void> _checkBanStatus() async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    try {
      final profile = await authService.getUserProfile();
      if (profile != null && profile['is_banned'] == true) {
        if (mounted) {
          _showBannedDialog(profile['ban_reason'] as String?);
        }
      }
    } catch (_) {
      // Silently fail — don't disrupt the user on network errors
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandTeal,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
