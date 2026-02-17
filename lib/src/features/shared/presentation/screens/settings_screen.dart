import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/utils/dialogs.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../core/utils/haptics.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.valueOrNull ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account
            _sectionTitle('Account'),
            _settingsCard([
              _settingsTile(
                icon: Icons.swap_horiz,
                title: 'Switch Role',
                subtitle:
                    'Currently: ${role == 'supplier' ? 'Supplier' : 'Trucker'}',
                onTap: () => _showSwitchRoleDialog(context, ref, role),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () => context.push('/forgot-password'),
              ),
            ]),
            const SizedBox(height: 16),

            // Preferences
            _sectionTitle('Preferences'),
            _settingsCard([
              _settingsTile(
                icon: Icons.language,
                title: 'Language',
                subtitle: ref.watch(localeProvider).languageCode == 'hi'
                    ? 'हिन्दी'
                    : 'English',
                onTap: () => _showLanguageDialog(context, ref),
              ),
            ]),
            const SizedBox(height: 16),

            // About
            _sectionTitle('About'),
            _settingsCard([
              _settingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () => _openUrl('https://tranzfort.com/terms'),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _openUrl('https://tranzfort.com/privacy'),
              ),
              const Divider(height: 1),
              _settingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: null,
              ),
            ]),
            const SizedBox(height: 16),

            // Data & Privacy
            _sectionTitle('Data & Privacy'),
            _settingsCard([
              // Data export - only show if feature flag enabled
              if (_isDataExportEnabled(ref))
                _settingsTile(
                  icon: Icons.download,
                  title: 'Download My Data',
                  subtitle: 'Export your data',
                  onTap: () => _showDataExportDialog(context, ref),
                ),
              if (_isDataExportEnabled(ref))
                const Divider(height: 1),
              _settingsTile(
                icon: Icons.delete_forever,
                title: 'Delete My Account',
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
                title: 'Logout',
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
            Text('Select Language',
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
    final newRoleLabel = newRole == 'supplier' ? 'Supplier' : 'Trucker';

    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Switch Role',
      description: 'Switch to $newRoleLabel? You will be signed out.',
      confirmText: 'Switch',
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
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete Account',
      description:
          'Your account will be scheduled for deletion within 30 days. '
          'Contact support@tranzfort.com to cancel.',
      confirmText: 'Delete',
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
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Logout',
      description: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) return;

    AppHaptics.onDestructive();
    invalidateAllUserProviders(ref);
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go('/login');
  }

  bool _isDataExportEnabled(WidgetRef ref) {
    // Check feature flag - for now, disabled by default
    // Can be enabled via remote config or local feature flags
    return false;
  }

  void _showDataExportDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Download My Data',
      description:
          'We will prepare a download of all your personal data including profile, loads, trips, and messages. '
          'This may take up to 24 hours. You will receive an email when ready.',
      confirmText: 'Request Export',
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
