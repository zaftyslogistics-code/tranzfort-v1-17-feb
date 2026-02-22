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
import '../../../../core/utils/animations.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton_loader.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../shared/widgets/tts_button.dart';

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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.messages),
        actions: [
          conversationsAsync.whenData((convs) {
            final isHi = ref.watch(localeProvider).languageCode == 'hi';
            return TtsButton(
              text: 'Read aloud',
              spokenText: isHi
                  ? 'संदेश। आपके ${convs.length} सक्रिय वार्तालाप हैं।'
                  : 'Messages. You have ${convs.length} conversations.',
              locale: isHi ? 'hi-IN' : 'en-IN',
              size: 22,
            );
          }).valueOrNull ?? const SizedBox.shrink(),
        ],
      ),
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
              title: AppLocalizations.of(context)!.noMessages,
              description: AppLocalizations.of(context)!.noData,
            );
          }

          // Phase 4A: Supplier view groups conversations by load
          final isSupplier = role == 'supplier';

          if (isSupplier) {
            return _SupplierGroupedInbox(
              conversations: conversations,
              currentUserId: userId ?? '',
              onRefresh: () => ref.invalidate(_conversationsProvider),
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
      final date = DateTime.parse(dateStr).toLocal();
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

/// Phase 4A: Supplier inbox grouped by load.
/// Groups conversations under load headers so suppliers can see
/// all trucker inquiries per load at a glance.
class _SupplierGroupedInbox extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final String currentUserId;
  final VoidCallback onRefresh;

  const _SupplierGroupedInbox({
    required this.conversations,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  State<_SupplierGroupedInbox> createState() => _SupplierGroupedInboxState();
}

class _SupplierGroupedInboxState extends State<_SupplierGroupedInbox> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    // Group conversations by load_id
    final grouped = <String, List<Map<String, dynamic>>>{};
    final loadMeta = <String, Map<String, dynamic>>{};

    for (final conv in widget.conversations) {
      final loadId = conv['load_id'] as String? ?? 'no_load';
      grouped.putIfAbsent(loadId, () => []);
      grouped[loadId]!.add(conv);
      // Store load metadata from first conversation
      if (!loadMeta.containsKey(loadId)) {
        loadMeta[loadId] = conv;
      }
    }

    // Sort groups: most recent message first
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aTime = grouped[a]!.first['last_message_at'] as String? ?? '';
        final bTime = grouped[b]!.first['last_message_at'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

    return RefreshIndicator(
      color: AppColors.brandTeal,
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final loadId = sortedKeys[index];
          final convs = grouped[loadId]!;
          final meta = loadMeta[loadId]!;
          final isCollapsed = _collapsed.contains(loadId);

          // Count total unread across all conversations for this load
          final totalUnread = convs.fold<int>(
            0, (sum, c) => sum + ((c['unread_count'] as int?) ?? 0),
          );

          final originCity = meta['origin_city'] as String? ??
              meta['load_origin_city'] as String? ?? '';
          final destCity = meta['dest_city'] as String? ??
              meta['load_dest_city'] as String? ?? '';
          final material = meta['material'] as String? ??
              meta['load_material'] as String? ?? '';
          final weight = meta['weight_tonnes'] ?? meta['load_weight_tonnes'] ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Load header
              InkWell(
                onTap: () => setState(() {
                  if (isCollapsed) {
                    _collapsed.remove(loadId);
                  } else {
                    _collapsed.add(loadId);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                    vertical: 10,
                  ),
                  color: AppColors.scaffoldBg,
                  child: Row(
                    children: [
                      Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brandTealLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.inventory_2,
                            size: 16, color: AppColors.brandTeal),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              originCity.isNotEmpty && destCity.isNotEmpty
                                  ? '$originCity → $destCity'
                                  : 'Load',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (material.isNotEmpty || weight.toString().isNotEmpty)
                              Text(
                                [
                                  if (material.isNotEmpty) material,
                                  if (weight.toString().isNotEmpty) '${weight}T',
                                ].join(' • '),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Trucker count + unread badge
                      Text(
                        '${convs.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.people_outline,
                          size: 14, color: AppColors.textTertiary),
                      if (totalUnread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            totalUnread > 99 ? '99+' : '$totalUnread',
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
                ),
              ),
              // Divider
              const Divider(height: 1, indent: 16, endIndent: 16),
              // Conversation tiles (collapsible)
              if (!isCollapsed)
                ...convs.asMap().entries.map((entry) {
                  return _ConversationTile(
                    conversation: entry.value,
                    currentUserId: widget.currentUserId,
                    currentRole: 'supplier',
                  ).staggerEntrance(entry.key);
                }),
            ],
          );
        },
      ),
    );
  }
}
