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

final _myTrucksProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return [];
  return ref.read(databaseServiceProvider).getMyTrucks(userId);
});

class MyFleetScreen extends ConsumerWidget {
  const MyFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trucksAsync = ref.watch(_myTrucksProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myFleet),
        actions: [
          trucksAsync.whenData((trucks) {
            final isHi = ref.watch(localeProvider).languageCode == 'hi';
            return TtsButton(
              text: 'Read aloud',
              spokenText: isHi
                  ? 'मेरा बेड़ा। आपके ${trucks.length} ट्रक रजिस्टर्ड हैं।'
                  : 'My Fleet. You have ${trucks.length} trucks registered.',
              locale: isHi ? 'hi-IN' : 'en-IN',
              size: 22,
            );
          }).valueOrNull ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRole: 'trucker'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-truck'),
        backgroundColor: AppColors.brandTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: trucksAsync.when(
        loading: () => const SkeletonLoader(
          itemCount: 3,
          type: SkeletonType.card,
        ),
        error: (e, _) => ErrorRetry(
          onRetry: () => ref.invalidate(_myTrucksProvider),
        ),
        data: (trucks) {
          if (trucks.isEmpty) {
            return EmptyState(
              icon: Icons.local_shipping_outlined,
              title: AppLocalizations.of(context)!.noTrucksYet,
              description: AppLocalizations.of(context)!.addYourFirstTruck,
              actionLabel: AppLocalizations.of(context)!.addTruck,
              onAction: () => context.push('/add-truck'),
            );
          }

          return RefreshIndicator(
            color: AppColors.brandTeal,
            onRefresh: () async => ref.invalidate(_myTrucksProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
              itemCount: trucks.length,
              itemBuilder: (context, index) {
                final truck = trucks[index];
                return _TruckCard(truck: truck).staggerEntrance(index);
              },
            ),
          );
        },
      ),
    );
  }
}

class _TruckCard extends ConsumerWidget {
  final Map<String, dynamic> truck;

  const _TruckCard({required this.truck});

  Future<void> _deleteTruck(BuildContext context, WidgetRef ref) async {
    final truckNumber = truck['truck_number'] as String? ?? 'this truck';
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.delete,
      description: '${l10n.delete} $truckNumber?',
      confirmText: l10n.delete,
      isDestructive: true,
    );
    if (confirmed != true) return;

    try {
      await ref.read(databaseServiceProvider).deleteTruck(truck['id']);
      ref.invalidate(_myTrucksProvider);
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = truck['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandTealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping,
                    color: AppColors.brandTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck['truck_number'] as String? ?? '-',
                      style: AppTypography.h3Subsection,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${truck['body_type'] ?? '-'} • ${truck['tyres'] ?? '-'} tyres • ${truck['capacity_tonnes'] ?? '-'}T',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusChip(status: status),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.textTertiary),
                tooltip: AppLocalizations.of(context)!.delete,
                onPressed: () => _deleteTruck(context, ref),
              ),
            ],
          ),
          if (status == 'rejected') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                truck['rejection_reason'] as String? ?? 'Rejected',
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
