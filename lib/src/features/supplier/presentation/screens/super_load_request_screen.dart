import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/gradient_button.dart';

class SuperLoadRequestScreen extends ConsumerStatefulWidget {
  final String loadId;

  const SuperLoadRequestScreen({super.key, required this.loadId});

  @override
  ConsumerState<SuperLoadRequestScreen> createState() =>
      _SuperLoadRequestScreenState();
}

class _SuperLoadRequestScreenState
    extends ConsumerState<SuperLoadRequestScreen> {
  bool _isLoading = false;

  Future<void> _handleRequest() async {
    // Check payout profile first
    final authService = ref.read(authServiceProvider);
    final db = ref.read(databaseServiceProvider);
    final userId = authService.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Please login again');
        context.go('/login');
      }
      return;
    }

    final load = await db.getLoadById(widget.loadId);
    if (load == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Load not found');
        context.go('/my-loads');
      }
      return;
    }

    final loadOwnerId = load['supplier_id'] as String?;
    if (loadOwnerId != userId) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'You can only request Super Load for your own loads');
        context.go('/my-loads');
      }
      return;
    }

    final isSuperLoad = load['is_super_load'] == true;
    if (isSuperLoad) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'This load is already a Super Load');
        context.go('/supplier/super-dashboard');
      }
      return;
    }

    final payout = await db.getPayoutProfile(userId);
    if (payout == null) {
      if (mounted) {
        AppDialogs.showSnackBar(context, 'Please add a payout profile first');
        context.push('/payout-profile');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await db.requestSuperLoad(widget.loadId);

      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Super Load requested!');
        context.go('/supplier/super-dashboard');
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
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Make Super Load')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandOrangeLight,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.brandOrange),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star, size: 48, color: AppColors.brandOrange),
                  const SizedBox(height: 16),
                  Text('Super Load', style: AppTypography.h2Section),
                  const SizedBox(height: 8),
                  Text(
                    'TranZfort guarantees a truck for your load. We handle matching, verification, and payment.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _benefitRow(Icons.check_circle, 'Guaranteed truck assignment'),
            _benefitRow(Icons.check_circle, 'Verified truckers only'),
            _benefitRow(Icons.check_circle, 'Secure payment via TranZfort'),
            _benefitRow(Icons.check_circle, 'Real-time tracking'),
            const Spacer(),
            GradientButton(
              text: 'Request Super Load',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleRequest,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Text(text, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
