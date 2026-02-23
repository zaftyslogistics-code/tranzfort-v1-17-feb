import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/cache/sqlite_cache.dart';
import '../models/bot_response.dart';
import '../models/conversation_state.dart';

/// Manages bot conversation lifecycle: creation, persistence, history, reset.
/// Extracted from BasicBotService to isolate state management concerns.
class ConversationManager {
  final Map<String, ConversationState> _conversations = {};

  static const int maxHistorySize = 100;

  /// Get or create conversation state for a user.
  ConversationState getState(String userId) {
    return _conversations.putIfAbsent(userId, () => ConversationState());
  }

  /// Check if a conversation exists for a user.
  bool hasConversation(String userId) => _conversations.containsKey(userId);

  /// Restore conversation from SQLite.
  Future<void> restore(String userId) async {
    if (_conversations.containsKey(userId)) return;
    try {
      final rows = await CacheService.db.query(
        'bot_conversations',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final json = rows.first['state_json'] as String;
        if (json.isNotEmpty) {
          _conversations[userId] = ConversationState.deserialize(json);
          debugPrint('ConversationManager: restored conversation for $userId');
        }
      }
    } catch (e) {
      debugPrint('ConversationManager: restore failed: $e');
    }
  }

  /// Save conversation to SQLite.
  Future<void> save(String userId) async {
    final state = _conversations[userId];
    if (state == null) return;
    try {
      await CacheService.db.insert(
        'bot_conversations',
        {
          'user_id': userId,
          'state_json': state.serialize(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('ConversationManager: save failed: $e');
    }
  }

  /// Get conversation history for UI restore.
  List<BotMessage>? getHistory(String userId) {
    final state = _conversations[userId];
    if (state == null || state.history.isEmpty) return null;
    return List.unmodifiable(state.history);
  }

  /// Add a user message to history.
  void addUserMessage(String userId, String text) {
    final state = getState(userId);
    state.addMessage(BotMessage(text: text, isUser: true));
    _trimHistory(state);
  }

  /// Add a bot response to history.
  void addBotMessage(String userId, BotResponse response) {
    final state = getState(userId);
    state.addMessage(BotMessage(
      text: response.text,
      isUser: false,
      suggestions: response.suggestions,
      actions: response.actions,
    ));
    _trimHistory(state);
  }

  /// Add a raw message to history (for greeting persistence).
  void addMessage(String userId, BotMessage message) {
    final state = getState(userId);
    state.addMessage(message);
    _trimHistory(state);
  }

  /// Reset conversation for a user (clear state + persisted data).
  void reset(String userId) {
    _conversations.remove(userId);
    try {
      CacheService.db.delete(
        'bot_conversations',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (_) {}
  }

  /// Reset all conversations.
  void resetAll() {
    _conversations.clear();
  }

  /// Parse a slot edit target from user input.
  /// E.g., "change origin" → "origin", "destination galat hai" → "destination"
  String? parseSlotEditTarget(String message) {
    final lower = message.toLowerCase().trim();
    const slotNames = [
      'origin', 'destination', 'material', 'weight', 'price',
      'price_type', 'advance_percentage', 'truck_type', 'tyres',
      'pickup_date', 'notes',
    ];
    const slotAliases = {
      'from': 'origin',
      'pickup': 'origin',
      'kahan se': 'origin',
      'to': 'destination',
      'delivery': 'destination',
      'kahan': 'destination',
      'maal': 'material',
      'wajan': 'weight',
      'rate': 'price',
      'kimat': 'price',
      'truck': 'truck_type',
      'tyre': 'tyres',
      'date': 'pickup_date',
      'tarikh': 'pickup_date',
      'note': 'notes',
    };

    for (final slot in slotNames) {
      if (lower.contains(slot)) return slot;
    }
    for (final entry in slotAliases.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  void _trimHistory(ConversationState state) {
    if (state.history.length > maxHistorySize) {
      state.history.removeRange(0, state.history.length - maxHistorySize);
    }
  }
}
