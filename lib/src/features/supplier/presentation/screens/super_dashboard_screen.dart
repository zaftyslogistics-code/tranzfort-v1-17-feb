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
                        '${load['material']} • ${load['weight_tonnes']} tonnes • ₹${load['price']}/ton',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),

                      // Task 7.6: Ops timeline
                      const SizedBox(height: 12),
                      _SuperLoadTimeline(
                        superStatus: load['super_status'] as String? ?? 'requested',
                        loadStatus: load['status'] as String? ?? 'active',
                      ),

                      // Task 7.3/7.7: Payment terms + commission
                      if (load['payment_term_days'] != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: AppColors.brandOrange),
                            const SizedBox(width: 4),
                            Text(
                              'Payment: ${load['payment_term_days']} days after POD',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.brandOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Builder(builder: (_) {
                        final price = (load['price'] as num?)?.toDouble() ?? 0;
                        final weight = (load['weight_tonnes'] as num?)?.toDouble() ?? 0;
                        final total = price * weight;
                        if (total <= 0) return const SizedBox.shrink();
                        final commission = (total * 0.05).round();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long, size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                'Commission: ₹$commission (5% of ₹${total.round()})',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

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

/// Task 7.6: Super Load ops timeline showing full lifecycle.
/// Stages: Requested → Processing → Assigned → Pickup → In Transit → POD → Paid
class _SuperLoadTimeline extends StatelessWidget {
  final String superStatus;
  final String loadStatus;

  const _SuperLoadTimeline({
    required this.superStatus,
    required this.loadStatus,
  });

  static const _stages = [
    'Requested',
    'Processing',
    'Assigned',
    'Pickup',
    'In Transit',
    'POD',
    'Paid',
  ];

  static const _stageIcons = [
    Icons.send,
    Icons.hourglass_top,
    Icons.person_pin,
    Icons.local_shipping,
    Icons.route,
    Icons.camera_alt,
    Icons.payments,
  ];

  int get _currentIndex {
    // Map super_status + load_status to timeline index
    switch (superStatus) {
      case 'requested':
        return 0;
      case 'processing':
        return 1;
      case 'assigned':
        // Check load status for more granularity
        if (loadStatus == 'in_transit') return 4;
        if (loadStatus == 'delivered') return 5;
        if (loadStatus == 'completed') return 6;
        if (loadStatus == 'booked') return 3;
        return 2;
      case 'completed':
        return 6;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_stages.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stageIdx = i ~/ 2;
              final isCompleted = stageIdx < currentIdx;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isCompleted
                      ? AppColors.brandOrange
                      : AppColors.textTertiary.withValues(alpha: 0.2),
                ),
              );
            }
            final stageIdx = i ~/ 2;
            final isCompleted = stageIdx <= currentIdx;
            final isCurrent = stageIdx == currentIdx;

            return Container(
              width: isCurrent ? 26 : 20,
              height: isCurrent ? 26 : 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.brandOrange
                    : AppColors.textTertiary.withValues(alpha: 0.15),
                border: isCurrent
                    ? Border.all(color: AppColors.brandOrange, width: 2)
                    : null,
              ),
              child: Icon(
                isCompleted && !isCurrent
                    ? Icons.check
                    : _stageIcons[stageIdx],
                size: isCurrent ? 12 : 10,
                color: isCompleted ? Colors.white : AppColors.textTertiary,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(_stages.length, (i) {
            final isCurrent = i == currentIdx;
            return Expanded(
              child: Text(
                _stages[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontSize: 8,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isCurrent
                      ? AppColors.brandOrange
                      : AppColors.textTertiary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
