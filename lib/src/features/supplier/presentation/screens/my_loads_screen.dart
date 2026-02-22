import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
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
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';

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
          title: Text(AppLocalizations.of(context)!.myLoads),
          actions: [
            loadsAsync.whenData((loads) {
              final active = loads.where((l) => ['active','booked','in_transit'].contains(l['status'])).length;
              final completed = loads.where((l) => ['completed','cancelled','expired'].contains(l['status'])).length;
              final isHi = ref.watch(localeProvider).languageCode == 'hi';
              return TtsButton(
                text: 'Read aloud',
                spokenText: isHi
                    ? 'मेरे लोड। $active एक्टिव, $completed पूर्ण।'
                    : 'My Loads. $active active, $completed completed.',
                locale: isHi ? 'hi-IN' : 'en-IN',
                size: 22,
              );
            }).valueOrNull ?? const SizedBox.shrink(),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.brandTeal,
            labelColor: AppColors.brandTeal,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.active),
              Tab(text: AppLocalizations.of(context)!.completed),
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
                    ['active', 'pending_approval', 'booked', 'in_transit', 'delivered'].contains(l['status']))
                .toList();
            final history = loads
                .where((l) => ['completed', 'cancelled', 'expired']
                    .contains(l['status']))
                .toList();

            final l10n = AppLocalizations.of(context)!;
            return TabBarView(
              children: [
                _buildLoadList(context, ref, active, l10n.noActiveLoads,
                    l10n.postYourFirstLoad),
                _buildLoadList(context, ref, history, l10n.noCompletedLoads,
                    l10n.noCompletedLoads),
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
        actionLabel: AppLocalizations.of(context)!.postLoad,
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.deactivateLoad,
      description: l10n.deactivateConfirm,
      confirmText: l10n.deactivateLoad,
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
        AppDialogs.showSuccessSnackBar(context, l10n.loadDeactivated);
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
              StatusChip(
                status: status,
                role: 'supplier',
                locale: ref.watch(localeProvider).languageCode,
              ),
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
                _actionIcon(context, Icons.chat_bubble_outline, AppLocalizations.of(context)!.messages,
                    () => context.push('/messages')),
                if (!isSuperLoad)
                  _actionIcon(
                      context,
                      Icons.star_outline,
                      AppLocalizations.of(context)!.requestSuperLoad,
                      () => context
                          .push('/super-load-request/${load['id']}'))
                else
                  _actionIcon(
                    context,
                    Icons.auto_awesome,
                    AppLocalizations.of(context)!.superDashboard,
                    () => context.push('/supplier/super-dashboard'),
                  ),
                _actionIcon(context, Icons.copy_outlined, 'Post Similar', () {
                  context.push('/post-load', extra: {
                    'origin_city': load['origin_city'],
                    'origin_state': load['origin_state'],
                    'dest_city': load['dest_city'],
                    'dest_state': load['dest_state'],
                    'material': load['material'],
                    'weight_tonnes': load['weight_tonnes'],
                    'required_truck_type': load['required_truck_type'],
                    'price': load['price'],
                    'price_type': load['price_type'],
                    'advance_percentage': load['advance_percentage'],
                  });
                }),
                _actionIcon(context, Icons.close, AppLocalizations.of(context)!.deactivateLoad, () {
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
        return Text(AppLocalizations.of(context)!.cancelled,
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
