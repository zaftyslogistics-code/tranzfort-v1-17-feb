import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/utils/validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/stat_card.dart';

class TruckerProfileScreen extends ConsumerWidget {
  const TruckerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final totalTripsAsync = ref.watch(truckerTotalTripsProvider);
    final ratingAsync = ref.watch(truckerRatingProvider);
    final completionAsync = ref.watch(truckerCompletionRateProvider);
    final fleetAsync = ref.watch(truckerFleetCountProvider);

    final profile = profileAsync.valueOrNull;
    final name = profile?['full_name'] as String? ?? 'Trucker';
    final email = profile?['email'] as String? ?? '';
    final mobile = profile?['mobile'] as String? ?? '';
    final verificationStatus =
        profile?['verification_status'] as String? ?? 'unverified';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.brandTealLight,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name, style: AppTypography.h2Section),
                  const SizedBox(height: 4),
                  StatusChip(status: verificationStatus),
                  const SizedBox(height: 8),
                  if ((ratingAsync.valueOrNull ?? 0) > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            color: AppColors.brandOrange, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          ratingAsync.valueOrNull?.toStringAsFixed(1) ?? '0.0',
                          style: AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Personal info
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal Info',
                      style: AppTypography.overline
                          .copyWith(letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  _infoRow(Icons.person, 'Name', name),
                  _infoRow(Icons.email, 'Email', email, onTap: () => _copyToClipboard(context, email, 'Email')),
                  _infoRow(Icons.phone, 'Mobile', Validators.displayIndianMobile(mobile), onTap: () => _copyToClipboard(context, mobile, 'Mobile')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.check_circle,
                    value: '${totalTripsAsync.valueOrNull ?? 0}',
                    label: 'Total Trips',
                    iconColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(
                  child: StatCard(
                    icon: Icons.local_shipping,
                    value: '${fleetAsync.valueOrNull ?? 0}',
                    label: 'Fleet Size',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.percent,
                    value:
                        '${completionAsync.valueOrNull?.toStringAsFixed(0) ?? '0'}%',
                    label: 'Completion Rate',
                    iconColor: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.cardGap),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () => context.push('/trucker-verification'),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Verification'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                side: const BorderSide(color: AppColors.brandTeal),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static void _copyToClipboard(BuildContext context, String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    AppDialogs.showSuccessSnackBar(context, '$label copied to clipboard');
  }

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.caption),
                  Text(value, style: AppTypography.bodyMedium),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.copy, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
