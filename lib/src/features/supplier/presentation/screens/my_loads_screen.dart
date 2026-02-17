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
import '../../../../core/utils/animations.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/status_chip.dart';

final _myLoadsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final userId = authService.currentUser?.id;
  if (userId == null) return [];
  return ref.read(databaseServiceProvider).getMyLoads(userId);
});

class MyLoadsScreen extends ConsumerWidget {
  const MyLoadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadsAsync = ref.watch(_myLoadsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('My Loads'),
          bottom: const TabBar(
            indicatorColor: AppColors.brandTeal,
            labelColor: AppColors.brandTeal,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentRole: 'supplier'),
        body: loadsAsync.when(
          loading: () => const SkeletonLoader(
            itemCount: 3,
            type: SkeletonType.card,
          ),
          error: (e, _) => ErrorRetry(
            onRetry: () => ref.invalidate(_myLoadsProvider),
          ),
          data: (loads) {
            final active = loads
                .where((l) =>
                    ['active', 'booked', 'in_transit'].contains(l['status']))
                .toList();
            final history = loads
                .where((l) => ['completed', 'cancelled', 'expired']
                    .contains(l['status']))
                .toList();

            return TabBarView(
              children: [
                _buildLoadList(context, ref, active, 'No active loads',
                    'Post a load to get started'),
                _buildLoadList(context, ref, history, 'No history',
                    'Completed loads will appear here'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadList(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> loads,
    String emptyTitle,
    String emptyDesc,
  ) {
    if (loads.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: emptyTitle,
        description: emptyDesc,
        actionLabel: 'Post Load',
        onAction: () => context.push('/post-load'),
      );
    }

    return RefreshIndicator(
      color: AppColors.brandTeal,
      onRefresh: () async => ref.invalidate(_myLoadsProvider),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        itemCount: loads.length,
        itemBuilder: (context, index) {
          final load = loads[index];
          return _LoadCard(load: load).staggerEntrance(index);
        },
      ),
    );
  }
}

class _LoadCard extends ConsumerWidget {
  final Map<String, dynamic> load;

  const _LoadCard({required this.load});

  Future<void> _deactivateLoad(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Deactivate Load',
      description: 'Are you sure? This load will be removed from search results.',
      confirmText: 'Deactivate',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(databaseServiceProvider).updateLoad(
        load['id'] as String,
        {'status': 'cancelled'},
      );

      ref.invalidate(supplierActiveLoadsCountProvider);
      ref.invalidate(supplierRecentLoadsProvider);
      ref.invalidate(_myLoadsProvider);

      if (context.mounted) {
        AppDialogs.showSuccessSnackBar(context, 'Load deactivated');
      }
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = load['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final isSuperLoad = load['is_super_load'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
        border: load['is_super_load'] == true
            ? Border.all(color: AppColors.brandOrange, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${load['origin_city']} → ${load['dest_city']}',
                  style: AppTypography.h3Subsection,
                ),
              ),
              StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${load['material']} • ${load['weight_tonnes']} tonnes • ₹${load['price']}/ton',
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.visibility, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('${load['views_count'] ?? 0}',
                  style: AppTypography.caption),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('${load['responses_count'] ?? 0}',
                  style: AppTypography.caption),
              if (isActive && load['expires_at'] != null) ...[
                const Spacer(),
                _ExpiryCountdown(expiresAt: load['expires_at'] as String),
              ],
            ],
          ),
          if (isActive) ...[
            const Divider(height: 24),
            Row(
              children: [
                _actionIcon(context, Icons.chat_bubble_outline, 'Responses',
                    () => context.push('/messages')),
                if (!isSuperLoad)
                  _actionIcon(
                      context,
                      Icons.star_outline,
                      'Make Super',
                      () => context
                          .push('/super-load-request/${load['id']}'))
                else
                  _actionIcon(
                    context,
                    Icons.auto_awesome,
                    'View Super Loads',
                    () => context.push('/supplier/super-dashboard'),
                  ),
                _actionIcon(context, Icons.edit_outlined, 'Edit',
                    () => context.push('/load-detail/${load['id']}')),
                _actionIcon(context, Icons.close, 'Deactivate', () {
                  _deactivateLoad(context, ref);
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionIcon(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppColors.textSecondary),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

class _ExpiryCountdown extends StatelessWidget {
  final String expiresAt;

  const _ExpiryCountdown({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    try {
      final expiry = DateTime.parse(expiresAt);
      final remaining = expiry.difference(DateTime.now());

      if (remaining.isNegative) {
        return Text('Expired',
            style: AppTypography.caption.copyWith(color: AppColors.error));
      }

      final isUrgent = remaining.inHours < 24;
      final color = isUrgent ? AppColors.error : AppColors.textTertiary;

      String label;
      if (remaining.inDays > 0) {
        final hours = remaining.inHours % 24;
        label = '${remaining.inDays}d ${hours}h left';
      } else if (remaining.inHours > 0) {
        label = '${remaining.inHours}h left';
      } else {
        label = '${remaining.inMinutes}m left';
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
