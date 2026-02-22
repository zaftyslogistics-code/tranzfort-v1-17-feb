import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tranzfort/l10n/app_localizations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/providers/auth_service_provider.dart';
import '../../features/bot/providers/bot_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);
    final roleAsync = ref.watch(userRoleProvider);

    final profile = profileAsync.valueOrNull;
    final role = roleAsync.valueOrNull ?? '';

    final userName = profile?['full_name'] as String? ?? 'User';
    final avatarUrl = profile?['avatar_url'] as String?;
    final verificationStatus =
        profile?['verification_status'] as String? ?? 'unverified';

    return Drawer(
      width: AppSpacing.drawerWidth,
      child: Column(
        children: [
          _buildHeader(context, userName, avatarUrl, role, verificationStatus),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.home_outlined,
                  label: l10n.dashboard,
                  onTap: () {
                    Navigator.pop(context);
                    context.go(role == 'supplier'
                        ? '/supplier-dashboard'
                        : '/trucker-dashboard');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.person_outline,
                  label: l10n.profile,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(role == 'supplier'
                        ? '/supplier-profile'
                        : '/trucker-profile');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.verified_user_outlined,
                  label: l10n.verification,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(role == 'supplier'
                        ? '/supplier-verification'
                        : '/trucker-verification');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.smart_toy_outlined,
                  label: l10n.botTitle,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/bot-chat');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: l10n.settings,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.help_outline,
                  label: l10n.helpSupport,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/help-support');
                  },
                ),
                const Divider(),
                _buildMenuItem(
                  context,
                  icon: Icons.swap_horiz,
                  label: l10n.switchRole,
                  onTap: () => _showSwitchRoleDialog(context, ref, role),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.logout,
                  label: l10n.logout,
                  isDestructive: true,
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    String? avatarUrl,
    String role,
    String verificationStatus,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandTeal, AppColors.brandTealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.20),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildPill(
                      role == 'supplier' ? l10n.supplier : l10n.trucker,
                      Colors.white.withValues(alpha: 0.20),
                      Colors.white,
                    ),
                    const SizedBox(width: 6),
                    _buildPill(
                      verificationStatus == 'verified'
                          ? l10n.verified
                          : verificationStatus == 'pending'
                              ? l10n.pending
                              : l10n.verification,
                      verificationStatus == 'verified'
                          ? AppColors.success.withValues(alpha: 0.30)
                          : verificationStatus == 'pending'
                              ? AppColors.warning.withValues(alpha: 0.30)
                              : Colors.white.withValues(alpha: 0.15),
                      Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textTertiary,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              // Invalidate BEFORE signOut (while ref is alive)
              invalidateAllUserProviders(ref);
              // A8-FIX: Clear bot state so next user doesn't see previous user's conversation
              ref.read(botServiceProvider).resetAllConversations();
              Navigator.pop(ctx);
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(l10n.logout, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showSwitchRoleDialog(
      BuildContext context, WidgetRef ref, String currentRole) {
    final l10n = AppLocalizations.of(context)!;
    final newRole = currentRole == 'supplier' ? 'trucker' : 'supplier';
    final newRoleLabel = newRole == 'supplier' ? l10n.supplier : l10n.trucker;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.switchRole),
        content: Text('${l10n.switchRole}: $newRoleLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final authService = ref.read(authServiceProvider);
              await authService.updateUserRole(newRole);
              invalidateAllUserProviders(ref);
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(l10n.switchRole),
          ),
        ],
      ),
    );
  }
}
