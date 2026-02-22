import 'dart:convert';
import 'bot_intent.dart';
import 'bot_response.dart';

class ConversationState {
  final Map<String, String?> _slots = {};
  final List<BotMessage> history = [];
  BotIntentType? activeIntent;
  bool confirmationShown = false;

  // P0-4: Track retry count per slot for escape hatch
  final Map<String, int> _retryCount = {};

  // P2-5: Serialize to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'slots': Map<String, String>.from(
        _slots.map((k, v) => MapEntry(k, v ?? '')),
      ),
      'activeIntent': activeIntent?.name,
      'confirmationShown': confirmationShown,
      'history': history.map((m) => m.toJson()).toList(),
      // A6-FIX: Serialize retry counts so restored sessions don't lose retry state
      'retryCount': Map<String, int>.from(_retryCount),
    };
  }

  // P2-5: Restore from JSON
  static ConversationState fromJson(Map<String, dynamic> json) {
    final state = ConversationState();
    final slots = json['slots'] as Map<String, dynamic>? ?? {};
    for (final entry in slots.entries) {
      final val = entry.value?.toString();
      if (val != null && val.isNotEmpty) {
        state._slots[entry.key] = val;
      }
    }
    final intentName = json['activeIntent'] as String?;
    if (intentName != null) {
      try {
        state.activeIntent = BotIntentType.values.firstWhere(
          (e) => e.name == intentName,
        );
      } catch (_) {}
    }
    state.confirmationShown = json['confirmationShown'] as bool? ?? false;
    final historyList = json['history'] as List<dynamic>? ?? [];
    for (final item in historyList) {
      if (item is Map<String, dynamic>) {
        state.history.add(BotMessage.fromJson(item));
      }
    }
    // A6-FIX: Restore retry counts
    final retryMap = json['retryCount'] as Map<String, dynamic>? ?? {};
    for (final entry in retryMap.entries) {
      state._retryCount[entry.key] = (entry.value as num).toInt();
    }
    return state;
  }

  String serialize() => jsonEncode(toJson());

  static ConversationState deserialize(String jsonStr) {
    try {
      return fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return ConversationState();
    }
  }

  void updateSlots(Map<String, String?> entities) {
    for (final entry in entities.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        _slots[entry.key] = entry.value;
      }
    }
  }

  bool hasSlot(String name) =>
      _slots[name] != null && _slots[name]!.isNotEmpty;

  // P1-5: Clear a specific slot by name
  void clearSlot(String name) {
    _slots.remove(name);
  }

  String getSlot(String name) => _slots[name] ?? '';

  Map<String, String?> get allSlots => Map.unmodifiable(_slots);

  bool hasAllRequiredSlots(BotIntentType intent) {
    switch (intent) {
      case BotIntentType.postLoad:
        return hasSlot('origin') &&
            hasSlot('destination') &&
            hasSlot('material') &&
            hasSlot('weight') &&
            hasSlot('price') &&
            hasSlot('price_type') &&
            hasSlot('advance_percentage') &&
            hasSlot('truck_type') &&
            hasSlot('pickup_date') &&
            hasSlot('notes');
      case BotIntentType.findLoads:
        return hasSlot('origin') || hasSlot('destination');
      default:
        return true;
    }
  }

  void setActiveIntent(BotIntentType type) {
    activeIntent = type;
  }

  void addMessage(BotMessage message) {
    history.add(message);
  }

  /// Remove the most recently filled slot and return its name.
  /// Returns null if no slots are filled.
  /// Slot fill order for post_load: origin → destination → material → weight → price → price_type → advance_percentage → truck_type → tyres → pickup_date
  String? clearLastSlot() {
    const postLoadOrder = [
      'notes', 'pickup_date', 'tyres', 'truck_type', 'advance_percentage', 'price_type',
      'price', 'weight', 'material', 'destination', 'origin',
    ];
    const findLoadsOrder = ['destination', 'origin'];

    final order = activeIntent == BotIntentType.postLoad
        ? postLoadOrder
        : activeIntent == BotIntentType.findLoads
            ? findLoadsOrder
            : _slots.keys.toList().reversed.toList();

    for (final slot in order) {
      if (hasSlot(slot)) {
        _slots.remove(slot);
        return slot;
      }
    }
    return null;
  }

  // P0-4: Retry count helpers
  int getRetryCount(String slot) => _retryCount[slot] ?? 0;

  void incrementRetry(String slot) {
    _retryCount[slot] = (_retryCount[slot] ?? 0) + 1;
  }

  void resetRetry(String slot) {
    _retryCount.remove(slot);
  }

  /// Determine which slot is currently being filled (the first empty one).
  String? get currentSlotBeingFilled {
    if (activeIntent == BotIntentType.postLoad) {
      const order = ['origin', 'destination', 'material', 'weight', 'price', 'price_type', 'advance_percentage', 'truck_type', 'tyres', 'pickup_date', 'notes'];
      for (final slot in order) {
        if (!hasSlot(slot)) return slot;
      }
    } else if (activeIntent == BotIntentType.findLoads) {
      if (!hasSlot('origin') && !hasSlot('destination')) return 'origin';
      if (!hasSlot('destination')) return 'destination';
      if (!hasSlot('search_truck_type')) return 'search_truck_type';
      if (!hasSlot('search_material')) return 'search_material';
    }
    return null;
  }

  void reset() {
    _slots.clear();
    _retryCount.clear();
    activeIntent = null;
    confirmationShown = false;
  }
}
