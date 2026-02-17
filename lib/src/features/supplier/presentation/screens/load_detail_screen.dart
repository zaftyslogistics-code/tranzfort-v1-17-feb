import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/tts_button.dart';

final _loadDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, loadId) async {
  return ref.read(databaseServiceProvider).getLoadById(loadId);
});

class LoadDetailScreen extends ConsumerWidget {
  final String loadId;

  const LoadDetailScreen({super.key, required this.loadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadFuture = ref.watch(_loadDetailProvider(loadId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Load Details'),
        actions: [
          if (loadFuture.valueOrNull != null) ...[
            TtsButton(
              text: _buildTtsText(loadFuture.valueOrNull!),
              size: 22,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share load',
              onPressed: () => _shareLoad(loadFuture.valueOrNull!),
            ),
          ],
        ],
      ),
      body: loadFuture.when(
        loading: () => const SkeletonLoader(
          itemCount: 4,
          type: SkeletonType.card,
        ),
        error: (e, _) => ErrorRetry(
          onRetry: () => ref.invalidate(_loadDetailProvider(loadId)),
        ),
        data: (load) {
          if (load == null) {
            return const Center(child: Text('Load not found'));
          }

          final status = load['status'] as String? ?? 'active';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${load['origin_city']} → ${load['dest_city']}',
                              style: AppTypography.h2Section,
                            ),
                          ),
                          StatusChip(status: status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${load['origin_state']} → ${load['dest_state']}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details
                _detailSection('Material & Weight', [
                  _detailRow('Material', load['material'] ?? '-'),
                  _detailRow(
                      'Weight', '${load['weight_tonnes'] ?? '-'} tonnes'),
                ]),
                const SizedBox(height: 16),

                _detailSection('Truck Requirements', [
                  _detailRow('Type',
                      load['required_truck_type'] ?? 'Any'),
                  _detailRow(
                      'Tyres',
                      (load['required_tyres'] as List?)
                              ?.join(', ') ??
                          'Any'),
                ]),
                const SizedBox(height: 16),

                _detailSection('Pricing', [
                  _detailRow('Price',
                      '₹${load['price']}/ton (${load['price_type'] ?? 'negotiable'})'),
                  _detailRow('Pickup Date',
                      load['pickup_date'] ?? '-'),
                ]),
                const SizedBox(height: 16),

                _detailSection('Stats', [
                  _detailRow(
                      'Views', '${load['views_count'] ?? 0}'),
                  _detailRow('Responses',
                      '${load['responses_count'] ?? 0}'),
                ]),
                const SizedBox(height: 24),

                // Actions
                if (status == 'active') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                              '/super-load-request/$loadId'),
                          icon: const Icon(Icons.star),
                          label: const Text('Make Super'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                                AppSpacing.buttonHeight),
                            side: const BorderSide(
                                color: AppColors.brandOrange),
                            foregroundColor: AppColors.brandOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await AppDialogs.confirm(
                              context,
                              title: 'Deactivate Load',
                              description: 'Are you sure? This load will be removed from search results.',
                              confirmText: 'Deactivate',
                              isDestructive: true,
                            );
                            if (confirmed) {
                              AppHaptics.onDestructive();
                              await ref.read(databaseServiceProvider).updateLoad(
                                loadId, {'status': 'cancelled'},
                              );
                              ref.invalidate(supplierActiveLoadsCountProvider);
                              ref.invalidate(supplierRecentLoadsProvider);
                              if (context.mounted) {
                                AppDialogs.showSuccessSnackBar(context, 'Load deactivated');
                                context.pop();
                              }
                            }
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Deactivate'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                                AppSpacing.buttonHeight),
                            side: const BorderSide(
                                color: AppColors.error),
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _buildTtsText(Map<String, dynamic> load) {
    return 'Load from ${load['origin_city']} to ${load['dest_city']}. '
        '${load['material']}, ${load['weight_tonnes']} tonnes. '
        'Price ${load['price']} rupees per ton. '
        'Truck type: ${load['required_truck_type'] ?? 'any'}. '
        'Pickup date: ${load['pickup_date'] ?? 'not specified'}.';
  }

  void _shareLoad(Map<String, dynamic> load) {
    final text = '''
🚛 TranZfort Load Available

📍 Route: ${load['origin_city']} → ${load['dest_city']}
📦 Material: ${load['material']}
⚖️ Weight: ${load['weight_tonnes']} tonnes
💰 Price: ₹${load['price']}/ton (${load['price_type'] ?? 'negotiable'})
🚚 Truck Type: ${load['required_truck_type'] ?? 'Any'}
📅 Pickup: ${load['pickup_date'] ?? '-'}

Download TranZfort to respond to this load.
''';
    Share.share(text.trim());
  }

  Widget _detailSection(String title, List<Widget> children) {
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
              style: AppTypography.overline
                  .copyWith(letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium),
          ),
        ],
      ),
    );
  }
}
