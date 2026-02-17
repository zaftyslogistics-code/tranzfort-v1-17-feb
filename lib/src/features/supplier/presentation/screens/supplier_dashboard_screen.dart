import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../core/services/smart_defaults_service.dart';

class SupplierDashboardScreen extends ConsumerWidget {
  const SupplierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final activeLoadsAsync = ref.watch(supplierActiveLoadsCountProvider);
    final unreadAsync = ref.watch(unreadChatsCountProvider);

    final profile = profileAsync.valueOrNull;
    final userName = profile?['full_name'] as String? ?? 'Supplier';
    final verificationStatus =
        profile?['verification_status'] as String? ?? 'unverified';
    final isVerified = verificationStatus == 'verified';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/messages'),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRole: 'supplier'),
      body: RefreshIndicator(
        color: AppColors.brandTeal,
        onRefresh: () async {
          ref.invalidate(supplierActiveLoadsCountProvider);
          ref.invalidate(supplierRecentLoadsProvider);
          ref.invalidate(userProfileProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Text('Welcome, $userName', style: AppTypography.h1Hero),
              const SizedBox(height: 4),
              if (!isVerified)
                GestureDetector(
                  onTap: () => context.push('/supplier-verification'),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Complete verification to post loads',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.warning),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.warning),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.inventory_2,
                      value: '${activeLoadsAsync.valueOrNull ?? 0}',
                      label: 'Active Loads',
                      onTap: () => context.go('/my-loads'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: StatCard(
                      icon: Icons.chat_bubble,
                      value: '${unreadAsync.valueOrNull ?? 0}',
                      label: 'Unread Chats',
                      iconColor: AppColors.brandOrange,
                      onTap: () => context.go('/messages'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Actions
              Text('Quick Actions',
                  style: AppTypography.overline
                      .copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 12),
              GradientButton(
                text: 'Post New Load',
                onPressed: isVerified
                    ? () => context.push('/post-load')
                    : () => AppDialogs.showSnackBar(
                          context, 'Complete verification to post loads'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isVerified
                          ? () async {
                              final (origin, dest) =
                                  await SmartDefaults.getLastRoute();
                              if (origin != null && origin.isNotEmpty) {
                                if (context.mounted) {
                                  context.push('/post-load');
                                }
                              } else {
                                if (context.mounted) {
                                  AppDialogs.showSnackBar(
                                      context, 'No previous load to repeat');
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('Repeat Last'),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppSpacing.buttonHeight),
                        side: const BorderSide(color: AppColors.brandTeal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/my-loads'),
                      icon: const Icon(Icons.list_alt, size: 18),
                      label: const Text('My Loads'),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppSpacing.buttonHeight),
                        side: const BorderSide(color: AppColors.brandTeal),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Recent Loads
              Text('Recent Loads',
                  style: AppTypography.overline
                      .copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final recentAsync =
                      ref.watch(supplierRecentLoadsProvider);
                  return recentAsync.when(
                    loading: () => const SkeletonLoader(
                      itemCount: 2,
                      type: SkeletonType.card,
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (loads) {
                      if (loads.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius),
                          ),
                          child: Center(
                            child: Text(
                              'No loads posted yet',
                              style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textTertiary),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: loads.map((load) {
                          return Container(
                            margin: const EdgeInsets.only(
                                bottom: AppSpacing.cardGap),
                            padding: const EdgeInsets.all(
                                AppSpacing.cardPadding),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.cardRadius),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: InkWell(
                              onTap: () => context.push(
                                  '/load-detail/${load['id']}'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${load['origin_city']} → ${load['dest_city']}',
                                          style:
                                              AppTypography.h3Subsection,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${load['material']} • ${load['weight_tonnes']} tonnes',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                  color: AppColors
                                                      .textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
