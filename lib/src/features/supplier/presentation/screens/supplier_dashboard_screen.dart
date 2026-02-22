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
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../core/services/smart_defaults_service.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';
import '../../../../shared/widgets/notification_bell.dart';

class SupplierDashboardScreen extends ConsumerWidget {
  const SupplierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);
    final activeLoadsAsync = ref.watch(supplierActiveLoadsCountProvider);
    final unreadAsync = ref.watch(unreadChatsCountProvider);

    final profile = profileAsync.valueOrNull;
    final userName = profile?['full_name'] as String? ?? l10n.supplier;
    final verificationStatus =
        profile?['verification_status'] as String? ?? 'unverified';
    final isVerified = verificationStatus == 'verified';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.dashboard),
        actions: [
          TtsButton(
            text: 'Read aloud',
            spokenText: ref.watch(localeProvider).languageCode == 'hi'
                ? 'नमस्ते $userName। आपके ${activeLoadsAsync.valueOrNull ?? 0} एक्टिव लोड हैं। वेरिफिकेशन स्थिति: ${verificationStatus == 'verified' ? 'वेरिफाइड' : 'वेरिफाइ नहीं हुआ'}।'
                : 'Welcome $userName. You have ${activeLoadsAsync.valueOrNull ?? 0} active loads. Verification: ${verificationStatus == 'verified' ? 'Verified' : 'Not verified'}.',
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
          const LanguageToggleButton(),
          const NotificationBell(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRole: 'supplier'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bot-chat'),
        backgroundColor: Colors.white,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/images/bot-avatar.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
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
              Text(l10n.welcomeUser(userName), style: AppTypography.h1Hero),
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
                            l10n.completeVerification,
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
              const SizedBox(height: 16),

              // Task 5.3: Pending bookings — "Needs Your Action"
              _PendingBookingsSection(),
              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.inventory_2,
                      value: '${activeLoadsAsync.valueOrNull ?? 0}',
                      label: l10n.activeLoads,
                      onTap: () => context.go('/my-loads'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: StatCard(
                      icon: Icons.chat_bubble,
                      value: '${unreadAsync.valueOrNull ?? 0}',
                      label: l10n.messages,
                      iconColor: AppColors.brandOrange,
                      onTap: () => context.go('/messages'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Quick Actions
              Text(l10n.quickActions,
                  style: AppTypography.overline
                      .copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 12),
              GradientButton(
                text: l10n.postLoad,
                onPressed: isVerified
                    ? () => context.push('/post-load')
                    : () => AppDialogs.showSnackBar(
                          context, l10n.completeVerification),
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
                                      context, l10n.noData);
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.replay, size: 18),
                      label: Text(l10n.repeatLast),
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
                      label: Text(l10n.myLoads),
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
              Text(l10n.recentLoads,
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
                    error: (e, _) => Text('${l10n.error}: $e'),
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
                              l10n.noData,
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

/// Task 5.3: "Needs Your Action" section showing pending booking requests.
class _PendingBookingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(supplierPendingBookingsProvider);

    return pendingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (pending) {
        if (pending.isEmpty) return const SizedBox.shrink();

        final isHi = ref.watch(localeProvider).languageCode == 'hi';

        return Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notification_important,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    isHi
                        ? 'आपकी कार्रवाई चाहिए (${pending.length})'
                        : 'Needs Your Action (${pending.length})',
                    style: AppTypography.h3Subsection
                        .copyWith(color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pending.map((load) => _PendingBookingCard(load: load)),
            ],
          ),
        );
      },
    );
  }
}

class _PendingBookingCard extends ConsumerWidget {
  final Map<String, dynamic> load;

  const _PendingBookingCard({required this.load});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHi = ref.watch(localeProvider).languageCode == 'hi';
    final origin = load['origin_city'] as String? ?? '';
    final dest = load['dest_city'] as String? ?? '';
    final material = load['material'] as String? ?? '';
    final weight = load['weight_tonnes']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$origin → $dest',
            style: AppTypography.bodyMedium
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$material • ${weight}T',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: () async {
                      final loadId = load['id'] as String?;
                      if (loadId == null) return;
                      try {
                        await ref.read(databaseServiceProvider).updateLoad(
                          loadId,
                          {'status': 'booked'},
                        );
                        ref.invalidate(supplierPendingBookingsProvider);
                        ref.invalidate(supplierActiveLoadsCountProvider);
                        if (context.mounted) {
                          AppDialogs.showSuccessSnackBar(
                            context,
                            isHi ? 'बुकिंग स्वीकृत!' : 'Booking approved!',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppDialogs.showErrorSnackBar(context, e);
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: Text(isHi ? 'स्वीकार' : 'Approve'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () async {
                      final loadId = load['id'] as String?;
                      if (loadId == null) return;
                      try {
                        await ref.read(databaseServiceProvider).updateLoad(
                          loadId,
                          {
                            'status': 'active',
                            'booked_by_trucker_id': null,
                            'booked_truck_id': null,
                            'booking_requested_at': null,
                          },
                        );
                        ref.invalidate(supplierPendingBookingsProvider);
                        ref.invalidate(supplierActiveLoadsCountProvider);
                        if (context.mounted) {
                          AppDialogs.showSuccessSnackBar(
                            context,
                            isHi ? 'बुकिंग अस्वीकृत' : 'Booking rejected',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppDialogs.showErrorSnackBar(context, e);
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: Text(isHi ? 'अस्वीकार' : 'Reject'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
