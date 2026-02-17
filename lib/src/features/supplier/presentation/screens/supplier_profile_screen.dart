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

class SupplierProfileScreen extends ConsumerWidget {
  const SupplierProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final supplierAsync = ref.watch(supplierDataProvider);
    final activeLoadsAsync = ref.watch(supplierActiveLoadsCountProvider);

    final profile = profileAsync.valueOrNull;
    final supplier = supplierAsync.valueOrNull;

    final name = profile?['full_name'] as String? ?? 'Supplier';
    final email = profile?['email'] as String? ?? '';
    final mobile = profile?['mobile'] as String? ?? '';
    final verificationStatus =
        profile?['verification_status'] as String? ?? 'unverified';
    final companyName = supplier?['company_name'] as String? ?? '-';

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
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Company info
            _infoSection('Company', [
              _infoRow(Icons.business, 'Company Name', companyName),
            ]),
            const SizedBox(height: 16),

            // Personal info
            _infoSection('Personal Info', [
              _infoRow(Icons.person, 'Name', name),
              _infoRow(Icons.email, 'Email', email, onTap: () => _copyToClipboard(context, email, 'Email')),
              _infoRow(Icons.phone, 'Mobile', Validators.displayIndianMobile(mobile), onTap: () => _copyToClipboard(context, mobile, 'Mobile')),
            ]),
            const SizedBox(height: 16),

            // Stats
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.inventory_2,
                    value: '${activeLoadsAsync.valueOrNull ?? 0}',
                    label: 'Active Loads',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions
            OutlinedButton.icon(
              onPressed: () => context.push('/supplier-verification'),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Verification'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                side: const BorderSide(color: AppColors.brandTeal),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/payout-profile'),
              icon: const Icon(Icons.account_balance),
              label: const Text('Payout Profile'),
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

  Widget _infoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.overline.copyWith(letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...children,
        ],
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
