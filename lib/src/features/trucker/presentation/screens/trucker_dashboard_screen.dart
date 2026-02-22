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
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/language_toggle_button.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';
import '../../../../shared/widgets/notification_bell.dart';

/// NAV-1: Trucker dashboard — mirrors supplier dashboard with trucker-specific stats & actions.
class TruckerDashboardScreen extends ConsumerWidget {
  const TruckerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);
    final activeTripsAsync = ref.watch(truckerActiveTripsCountProvider);
    final fleetCountAsync = ref.watch(truckerFleetCountProvider);
    final unreadAsync = ref.watch(unreadChatsCountProvider);

    final profile = profileAsync.valueOrNull;
    final userName = profile?['full_name'] as String? ?? l10n.trucker;
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
                ? 'नमस्ते $userName। आपकी ${activeTripsAsync.valueOrNull ?? 0} एक्टिव ट्रिप हैं। बेड़े में ${fleetCountAsync.valueOrNull ?? 0} ट्रक। वेरिफिकेशन: ${verificationStatus == 'verified' ? 'वेरिफाइड' : 'वेरिफाइ नहीं हुआ'}।'
                : 'Welcome $userName. You have ${activeTripsAsync.valueOrNull ?? 0} active trips. Fleet: ${fleetCountAsync.valueOrNull ?? 0} trucks. Verification: ${verificationStatus == 'verified' ? 'Verified' : 'Not verified'}.',
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
          const LanguageToggleButton(),
          const NotificationBell(),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRole: 'trucker'),
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
          ref.invalidate(truckerActiveTripsCountProvider);
          ref.invalidate(truckerFleetCountProvider);
          ref.invalidate(userProfileProvider);
          ref.invalidate(unreadChatsCountProvider);
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
                  onTap: () => context.push('/trucker-verification'),
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
              const SizedBox(height: 24),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.assignment,
                      value: '${activeTripsAsync.valueOrNull ?? 0}',
                      label: l10n.myTrips,
                      onTap: () => context.go('/my-trips'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: StatCard(
                      icon: Icons.local_shipping,
                      value: '${fleetCountAsync.valueOrNull ?? 0}',
                      label: l10n.myFleet,
                      iconColor: AppColors.brandOrange,
                      onTap: () => context.go('/my-fleet'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: StatCard(
                      icon: Icons.chat_bubble,
                      value: '${unreadAsync.valueOrNull ?? 0}',
                      label: l10n.messages,
                      iconColor: AppColors.info,
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
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      text: l10n.findLoads,
                      onPressed: () => context.push('/find-loads'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: AppSpacing.buttonHeight,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/navigation'),
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Navigate'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/my-fleet'),
                      icon: const Icon(Icons.local_shipping, size: 18),
                      label: Text(l10n.myFleet),
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
                      onPressed: () => context.push('/add-truck'),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addTruck),
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

              // Active Trips section
              Text(l10n.myTrips,
                  style: AppTypography.overline
                      .copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 12),
              Consumer(
                builder: (context, ref, _) {
                  final tripsAsync = ref.watch(truckerActiveTripsCountProvider);
                  return tripsAsync.when(
                    loading: () => const SkeletonLoader(
                      itemCount: 2,
                      type: SkeletonType.card,
                    ),
                    error: (e, _) => Text('${l10n.error}: $e'),
                    data: (count) {
                      if (count == 0) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.assignment_outlined,
                                    size: 40, color: AppColors.textTertiary),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.noData,
                                  style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textTertiary),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => context.push('/find-loads'),
                                  child: Text(l10n.findLoads),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.cardRadius),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: InkWell(
                          onTap: () => context.go('/my-trips'),
                          child: Row(
                            children: [
                              const Icon(Icons.assignment,
                                  color: AppColors.brandTeal),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '$count active trip${count > 1 ? 's' : ''}',
                                  style: AppTypography.h3Subsection,
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textTertiary),
                            ],
                          ),
                        ),
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
