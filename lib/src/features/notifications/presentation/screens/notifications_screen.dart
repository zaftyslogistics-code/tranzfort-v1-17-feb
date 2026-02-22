import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_service_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

final _notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return [];
  return ref.read(notificationServiceProvider).getNotifications(userId);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(_notificationsProvider);
    final userId = ref.read(authServiceProvider).currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (userId != null)
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationServiceProvider)
                    .markAllAsRead(userId);
                ref.invalidate(_notificationsProvider);
              },
              child: Text(
                'Mark all read',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandTeal,
                ),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const SkeletonLoader(itemCount: 5),
        error: (e, _) => ErrorRetry(
          onRetry: () => ref.invalidate(_notificationsProvider),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              description: 'You\'re all caught up!',
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: notifications.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationTile(
                notification: notif,
                onTap: () => _handleTap(context, ref, notif),
              );
            },
          );
        },
      ),
    );
  }

  void _handleTap(
      BuildContext context, WidgetRef ref, Map<String, dynamic> notif) async {
    final notifId = notif['id'] as String?;
    final isRead = notif['is_read'] as bool? ?? false;

    if (notifId == null) return;

    if (!isRead) {
      try {
        await ref.read(notificationServiceProvider).markAsRead(notifId);
        ref.invalidate(_notificationsProvider);
      } catch (e) {
        // Silently fail on mark-as-read errors
        debugPrint('Failed to mark notification as read: $e');
      }
    }

    // Deep link based on notification type
    final data = notif['data'] as Map<String, dynamic>?;
    final loadId = data?['load_id'] as String?;
    
    if (loadId != null && loadId.isNotEmpty && context.mounted) {
      try {
        context.push('/load/$loadId');
      } catch (e) {
        debugPrint('Navigation error: $e');
      }
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    final type = notification['type'] as String? ?? '';
    final isRead = notification['is_read'] as bool? ?? false;
    final createdAt = notification['created_at'] as String?;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? null : AppColors.brandTealLight.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _iconColor(type).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(type), size: 20, color: _iconColor(type)),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(createdAt),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.brandTeal,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'booking_request':
        return Icons.local_shipping_outlined;
      case 'booking_approved':
        return Icons.check_circle_outline;
      case 'booking_rejected':
        return Icons.cancel_outlined;
      case 'load_completed':
        return Icons.verified_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'booking_request':
        return AppColors.brandOrange;
      case 'booking_approved':
        return AppColors.success;
      case 'booking_rejected':
        return AppColors.error;
      case 'load_completed':
        return AppColors.brandTeal;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
