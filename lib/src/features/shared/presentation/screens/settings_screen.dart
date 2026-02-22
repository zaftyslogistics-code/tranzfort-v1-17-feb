import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../core/utils/haptics.dart';
import '../../../bot/providers/bot_provider.dart';
import '../../../../shared/widgets/tts_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.valueOrNull ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          TtsButton(
            text: 'Read aloud',
            spokenText: ref.watch(localeProvider).languageCode == 'hi'
                ? 'सेटिंग्स। अकाउंट, भाषा, और अप्प की जानकारी यहां मिलेगी।'
                : 'Settings. Manage your account, language preference, and app information here.',
            locale: ref.watch(localeProvider).languageCode == 'hi' ? 'hi-IN' : 'en-IN',
            size: 22,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account
            _sectionTitle(l10n.account),
            _settingsCard([
              _settingsTile(
                icon: Icons.swap_horiz,
                title: l10n.switchRole,
                subtitle:
                    role == 'supplier' ? l10n.supplier : l10n.trucker,
                onTap: () => _showSwitchRoleDialog(context, ref, role),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.lock_outline,
                title: l10n.changePassword,
                onTap: () => context.push('/forgot-password'),
              ),
            ]),
            const SizedBox(height: 16),

            // Preferences
            _sectionTitle(l10n.settings),
            _settingsCard([
              _settingsTile(
                icon: Icons.language,
                title: l10n.language,
                subtitle: ref.watch(localeProvider).languageCode == 'hi'
                    ? 'हिन्दी'
                    : 'English',
                onTap: () => _showLanguageDialog(context, ref),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.auto_awesome,
                title: 'AI & Voice',
                subtitle: 'Download AI models for bot, voice, transcription',
                onTap: () => context.push('/ai-settings'),
              ),
            ]),
            const SizedBox(height: 16),

            // About
            _sectionTitle(l10n.about),
            _settingsCard([
              _settingsTile(
                icon: Icons.description_outlined,
                title: l10n.termsOfService,
                onTap: () => _openUrl('https://tranzfort.com/terms'),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                onTap: () => _openUrl('https://tranzfort.com/privacy'),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.info_outline,
                title: l10n.appVersion,
                subtitle: '1.0.0',
                onTap: null,
              ),
            ]),
            const SizedBox(height: 16),

            // Data & Privacy
            _sectionTitle(l10n.privacyPolicy),
            _settingsCard([
              // Data export - only show if feature flag enabled
              if (_isDataExportEnabled(ref))
                _settingsTile(
                  icon: Icons.download,
                  title: l10n.dataExport,
                  subtitle: l10n.dataExport,
                  onTap: () => _showDataExportDialog(context, ref),
                ),
              if (_isDataExportEnabled(ref))
                const Divider(height: 1),
              _settingsTile(
                icon: Icons.delete_forever,
                title: l10n.deleteAccount,
                titleColor: AppColors.error,
                onTap: () => _showDeleteAccountDialog(context, ref),
              ),
            ]),
            const SizedBox(height: 16),

            // Danger zone
            _sectionTitle(''),
            _settingsCard([
              _settingsTile(
                icon: Icons.logout,
                title: l10n.logout,
                titleColor: AppColors.error,
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    if (title.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: AppTypography.overline.copyWith(letterSpacing: 0.8),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: titleColor ?? AppColors.textSecondary, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary))
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right,
              size: 20, color: AppColors.textTertiary)
          : null,
      onTap: onTap,
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(localeProvider).languageCode;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.language,
                style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                current == 'en' ? Icons.radio_button_checked : Icons.radio_button_off,
                color: current == 'en' ? AppColors.brandTeal : AppColors.textTertiary,
              ),
              title: const Text('English'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('en');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                current == 'hi' ? Icons.radio_button_checked : Icons.radio_button_off,
                color: current == 'hi' ? AppColors.brandTeal : AppColors.textTertiary,
              ),
              title: const Text('हिन्दी (Hindi)'),
              onTap: () {
                ref.read(localeProvider.notifier).setLocale('hi');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSwitchRoleDialog(
      BuildContext context, WidgetRef ref, String currentRole) async {
    final newRole = currentRole == 'supplier' ? 'trucker' : 'supplier';
    final l10n = AppLocalizations.of(context)!;
    final newRoleLabel = newRole == 'supplier' ? l10n.supplier : l10n.trucker;

    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.switchRole,
      description: '${l10n.switchRole}: $newRoleLabel?',
      confirmText: l10n.switchRole,
    );

    if (!confirmed || !context.mounted) return;

    AppHaptics.onPrimaryAction();
    final authService = ref.read(authServiceProvider);
    await authService.updateUserRole(newRole);
    invalidateAllUserProviders(ref);
    await authService.signOut();
    if (context.mounted) context.go('/login');
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.deleteAccount,
      description: l10n.deleteAccountConfirm,
      confirmText: l10n.delete,
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

    AppHaptics.onDestructive();
    try {
      final authService = ref.read(authServiceProvider);
      final db = ref.read(databaseServiceProvider);
      final userId = authService.currentUser!.id;

      await db.updateProfile(userId, {
        'data_deletion_requested_at': DateTime.now().toIso8601String(),
      });

      if (context.mounted) {
        AppDialogs.showSuccessSnackBar(
          context,
          'Account deletion requested. Contact support@tranzfort.com to cancel.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.logout,
      description: l10n.logoutConfirm,
      confirmText: l10n.logout,
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

    AppHaptics.onDestructive();
    invalidateAllUserProviders(ref);
    // A8-FIX: Clear bot state so next user doesn't see previous user's conversation
    ref.read(botServiceProvider).resetAllConversations();
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go('/login');
  }

  bool _isDataExportEnabled(WidgetRef ref) {
    // Check feature flag - for now, disabled by default
    // Can be enabled via remote config or local feature flags
    return false;
  }

  void _showDataExportDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.confirm(
      context,
      title: l10n.dataExport,
      description: l10n.dataExport,
      confirmText: l10n.submit,
    );

    if (!confirmed || !context.mounted) return;

    try {
      final db = ref.read(databaseServiceProvider);
      final userId = ref.read(authServiceProvider).currentUser!.id;

      // Record data export request
      await db.updateProfile(userId, {
        'data_export_requested_at': DateTime.now().toIso8601String(),
      });

      if (context.mounted) {
        AppDialogs.showSuccessSnackBar(
          context,
          'Data export requested. You will receive an email when ready.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppDialogs.showErrorSnackBar(context, e);
      }
    }
  }
}
