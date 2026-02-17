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
import '../../../../core/utils/animations.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

final _conversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.read(authServiceProvider).currentUser?.id;
  if (userId == null) return [];
  return ref.read(databaseServiceProvider).getConversationsByUser(userId);
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(_conversationsProvider);
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.valueOrNull ?? 'supplier';
    final userId = ref.read(authServiceProvider).currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('Messages')),
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavBar(currentRole: role),
      body: conversationsAsync.when(
        loading: () => const SkeletonLoader(
          itemCount: 5,
          type: SkeletonType.chat,
        ),
        error: (e, _) => ErrorRetry(
          onRetry: () => ref.invalidate(_conversationsProvider),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              description: role == 'supplier'
                  ? 'Truckers will contact you when they find your loads'
                  : 'Start chatting by finding a load',
            );
          }

          return RefreshIndicator(
            color: AppColors.brandTeal,
            onRefresh: () async =>
                ref.invalidate(_conversationsProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  currentUserId: userId ?? '',
                  currentRole: role,
                ).staggerEntrance(index);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String currentUserId;
  final String currentRole;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    // Show the OTHER party's name and avatar
    final isSupplier = currentRole == 'supplier';
    final otherName = isSupplier
        ? (conversation['trucker_name'] as String? ?? 'Trucker')
        : (conversation['supplier_name'] as String? ?? 'Supplier');
    final otherAvatar = isSupplier
        ? conversation['trucker_avatar'] as String?
        : conversation['supplier_avatar'] as String?;

    final lastMessage =
        conversation['last_message_text'] as String? ?? 'No messages yet';
    final lastMessageAt = conversation['last_message_at'] as String?;
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final hasUnread = unreadCount > 0;
    final initial = otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';

    return InkWell(
      onTap: () => context.push('/chat/${conversation['id']}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: 10,
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.brandTealLight,
              backgroundImage:
                  otherAvatar != null ? NetworkImage(otherAvatar) : null,
              child: otherAvatar == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: AppColors.brandTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage,
                    style: AppTypography.bodySmall.copyWith(
                      color: hasUnread
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastMessageAt != null)
                  Text(
                    _formatTime(lastMessageAt),
                    style: AppTypography.caption.copyWith(
                      color: hasUnread
                          ? AppColors.brandTeal
                          : AppColors.textTertiary,
                      fontWeight:
                          hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[date.weekday - 1];
      }
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }
}
