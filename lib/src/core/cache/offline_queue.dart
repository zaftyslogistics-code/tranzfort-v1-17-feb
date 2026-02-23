import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'sqlite_cache.dart';

/// Task 9.3: Offline Action Queue.
/// Queues mutations (book_load, post_load, send_message, update_trip_stage)
/// when offline and processes them oldest-first on connectivity restore.
class OfflineQueue {
  static const _table = 'pending_actions';
  static const int _maxRetries = 3;

  /// Enqueue an action for later processing.
  static Future<int> enqueue({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final db = CacheService.db;
    final id = await db.insert(_table, {
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
    debugPrint('OfflineQueue: enqueued $actionType (id=$id)');
    return id;
  }

  /// Get all pending actions, oldest first.
  static Future<List<PendingAction>> getPending() async {
    final db = CacheService.db;
    final rows = await db.query(
      _table,
      where: 'retry_count < ?',
      whereArgs: [_maxRetries],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => PendingAction.fromRow(r)).toList();
  }

  /// Get count of pending actions.
  static Future<int> pendingCount() async {
    final db = CacheService.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE retry_count < ?',
      [_maxRetries],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of permanently failed actions.
  static Future<int> failedCount() async {
    final db = CacheService.db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE retry_count >= ?',
      [_maxRetries],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark an action as completed (remove from queue).
  static Future<void> markDone(int id) async {
    final db = CacheService.db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    debugPrint('OfflineQueue: completed action id=$id');
  }

  /// Increment retry count for a failed action.
  static Future<void> incrementRetry(int id) async {
    final db = CacheService.db;
    await db.rawUpdate(
      'UPDATE $_table SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Process the queue. Caller provides the executor function.
  /// Returns the number of successfully processed actions.
  static Future<int> processQueue(
    Future<bool> Function(PendingAction action) executor,
  ) async {
    final pending = await getPending();
    if (pending.isEmpty) return 0;

    debugPrint('OfflineQueue: processing ${pending.length} pending actions');
    int successCount = 0;

    for (final action in pending) {
      try {
        final success = await executor(action);
        if (success) {
          await markDone(action.id);
          successCount++;
        } else {
          await incrementRetry(action.id);
        }
      } catch (e) {
        debugPrint('OfflineQueue: action ${action.id} failed: $e');
        await incrementRetry(action.id);
      }
    }

    debugPrint('OfflineQueue: processed $successCount/${pending.length} actions');
    return successCount;
  }

  /// Clear all actions (e.g. on logout).
  static Future<void> clearAll() async {
    final db = CacheService.db;
    await db.delete(_table);
    debugPrint('OfflineQueue: cleared all actions');
  }

  /// Remove permanently failed actions.
  static Future<int> clearFailed() async {
    final db = CacheService.db;
    final count = await db.delete(
      _table,
      where: 'retry_count >= ?',
      whereArgs: [_maxRetries],
    );
    debugPrint('OfflineQueue: cleared $count failed actions');
    return count;
  }
}

/// Represents a pending offline action.
class PendingAction {
  final int id;
  final String actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  const PendingAction({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
  });

  factory PendingAction.fromRow(Map<String, dynamic> row) {
    return PendingAction(
      id: row['id'] as int,
      actionType: row['action_type'] as String,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      retryCount: row['retry_count'] as int,
    );
  }
}
