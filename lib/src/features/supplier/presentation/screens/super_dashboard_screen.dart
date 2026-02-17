import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/status_chip.dart';

final _superLoadsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return [];
  return ref.read(databaseServiceProvider).getSuperLoads(userId);
});

class SuperDashboardScreen extends ConsumerWidget {
  const SuperDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final superLoadsAsync = ref.watch(_superLoadsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Super Loads')),
      bottomNavigationBar: const BottomNavBar(currentRole: 'supplier'),
      body: superLoadsAsync.when(
        loading: () => const SkeletonLoader(
          itemCount: 3,
          type: SkeletonType.card,
        ),
        error: (e, _) => ErrorRetry(
          onRetry: () => ref.invalidate(_superLoadsProvider),
        ),
        data: (loads) {
          if (loads.isEmpty) {
            return EmptyState(
              icon: Icons.star_outline,
              title: 'No Super Loads',
              description: 'Make a load "Super" for guaranteed truck assignment',
            );
          }

          return RefreshIndicator(
            color: AppColors.brandTeal,
            onRefresh: () async => ref.invalidate(_superLoadsProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
              itemCount: loads.length,
              itemBuilder: (context, index) {
                final load = loads[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius),
                    boxShadow: AppColors.superLoadGlow,
                    border:
                        Border.all(color: AppColors.brandOrange, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.brandOrange, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${load['origin_city']} → ${load['dest_city']}',
                              style: AppTypography.h3Subsection,
                            ),
                          ),
                          StatusChip(
                              status: load['super_status'] ?? 'requested'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${load['material']} • ${load['weight_tonnes']} tonnes',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            context.push('/load-detail/${load['id']}'),
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
