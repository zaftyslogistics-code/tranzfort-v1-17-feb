import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/animations.dart';
import '../../../../core/utils/dialogs.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateUserRole(role);

      // Create role-specific data
      final db = ref.read(databaseServiceProvider);
      final userId = authService.currentUser!.id;

      if (role == 'supplier') {
        await db.createSupplierData(userId, {});
      } else {
        await db.createTruckerData(userId, {});
      }

      // Refresh derived user providers and wait until role is resolved
      // before navigating so router guards don't bounce back to role-selection.
      invalidateAllUserProviders(ref);
      await ref.read(userRoleProvider.future);

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      if (role == 'supplier') {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Text(
                'What describes\nyou best?',
                style: AppTypography.h1Hero,
              ).staggerEntrance(0),
              const SizedBox(height: 8),
              Text(
                'Choose your role to get started',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ).staggerEntrance(1),
              const SizedBox(height: 48),
              _RoleCard(
                title: 'I am a Supplier',
                subtitle: 'Post Loads, Find Trucks, Track Deliveries',
                icon: Icons.factory_outlined,
                onTap: _isLoading ? null : () => _selectRole('supplier'),
              ).staggerEntrance(2),
              const SizedBox(height: AppSpacing.cardGap),
              _RoleCard(
                title: 'I am a Trucker',
                subtitle: 'Find Loads, Manage Fleet, Get Paid',
                icon: Icons.local_shipping_outlined,
                onTap: _isLoading ? null : () => _selectRole('trucker'),
              ).staggerEntrance(3),
              if (_isLoading) ...[
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandTeal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppSpacing.fast,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: _isPressed
                  ? AppColors.brandTeal
                  : AppColors.borderDefault,
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brandTealLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: AppColors.brandTeal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.h3Subsection,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
