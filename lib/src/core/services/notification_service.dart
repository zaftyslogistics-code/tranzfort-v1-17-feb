import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing in-app notifications via Supabase Realtime.
class NotificationService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  final _unreadCountController = StreamController<int>.broadcast();
  int _unreadCount = 0;

  NotificationService(this._supabase);

  /// Stream of unread notification count for badge display.
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int get unreadCount => _unreadCount;

  /// Start listening for new notifications via Realtime.
  void startListening(String userId) {
    _channel?.unsubscribe();
    _channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _unreadCount++;
            _unreadCountController.add(_unreadCount);
          },
        )
        .subscribe();

    // Fetch initial unread count
    _fetchUnreadCount(userId);
  }

  Future<void> _fetchUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .count();
      _unreadCount = response.count;
      _unreadCountController.add(_unreadCount);
    } catch (_) {}
  }

  /// Get all notifications for the current user, newest first.
  Future<List<Map<String, dynamic>>> getNotifications(String userId, {int limit = 50}) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
    if (_unreadCount > 0) {
      _unreadCount--;
      _unreadCountController.add(_unreadCount);
    }
  }

  /// Mark all notifications as read for a user.
  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
    _unreadCount = 0;
    _unreadCountController.add(_unreadCount);
  }

  void stopListening() {
    _channel?.unsubscribe();
    _channel = null;
  }

  void dispose() {
    stopListening();
    _unreadCountController.close();
  }
}
