import '../models/bot_intent.dart';
import '../models/conversation_state.dart';
import 'entity_extractor.dart';
import 'prompt_composer.dart';

/// Manages slot-filling state for multi-turn bot conversations.
/// Tracks required slots, validates input, handles retries and skips.
class SlotFiller {
  final EntityExtractor _entityExtractor;
  final PromptComposer? _promptComposer;

  static const int maxRetries = 5;

  SlotFiller(this._entityExtractor, [this._promptComposer]);

  /// Slot order for each intent type.
  static const Map<BotIntentType, List<String>> slotOrder = {
    BotIntentType.postLoad: [
      'origin', 'destination', 'material', 'weight', 'price',
      'price_type', 'advance_percentage', 'truck_type', 'tyres',
      'pickup_date', 'notes',
    ],
    BotIntentType.findLoads: [
      'origin', 'destination', 'search_truck_type', 'search_material',
    ],
    BotIntentType.superLoad: [
      'origin', 'destination', 'material', 'weight', 'truck_count',
      'price', 'advance', 'payment_term', 'pickup_date',
    ],
    BotIntentType.navigateTo: ['origin', 'destination'],
    BotIntentType.bookLoad: ['truck_selection'],
  };

  /// Slots that can be skipped (have defaults).
  static const _skippableSlots = {
    'price_type', 'advance_percentage', 'truck_type', 'tyres',
    'pickup_date', 'notes', 'search_truck_type', 'search_material',
  };

  /// Get the next unfilled slot for the given intent.
  String? getNextSlot(BotIntentType intent, ConversationState state) {
    final order = slotOrder[intent];
    if (order == null) return null;
    for (final slot in order) {
      if (!state.hasSlot(slot)) return slot;
    }
    return null; // All slots filled
  }

  /// Check if all required slots are filled.
  bool allSlotsFilled(BotIntentType intent, ConversationState state) {
    return getNextSlot(intent, state) == null;
  }

  /// Get the prompt for the next missing slot.
  String getSlotPrompt(BotIntentType intent, ConversationState state, String language) {
    final slot = getNextSlot(intent, state);
    if (slot == null) return '';

    final isRetry = state.getRetryCount(slot) > 0;
    final taskName = _intentToTaskName(intent);

    // Use PromptComposer if available
    final composer = _promptComposer;
    if (composer != null) {
      return composer.slotPrompt(taskName, slot, isRetry: isRetry);
    }

    // Fallback: hardcoded prompts
    return _fallbackSlotPrompt(slot, language, isRetry);
  }

  /// Process user input for the current slot being filled.
  /// Returns true if the slot was successfully filled.
  bool processSlotInput(
    String message,
    String language,
    BotIntentType intent,
    ConversationState state,
  ) {
    final currentSlot = getNextSlot(intent, state);
    if (currentSlot == null) return true; // All filled

    // Targeted extraction for the current slot only
    final entities = _entityExtractor.extractForSlot(
      message,
      language,
      currentSlot,
      existingSlots: state.allSlots,
    );
    state.updateSlots(entities);

    // If extraction found nothing, try raw input fallback
    if (entities.isEmpty || !state.hasSlot(currentSlot)) {
      _tryRawInputForSlot(state, currentSlot, message.trim());
    }

    // Validate city slots
    if ((currentSlot == 'origin' || currentSlot == 'destination') &&
        state.hasSlot(currentSlot)) {
      final raw = state.getSlot(currentSlot);
      if (raw.isNotEmpty) {
        final resolved = _entityExtractor.resolveCity(raw);
        if (resolved != null && resolved != raw) {
          state.updateSlots({currentSlot: resolved});
        }
      }
    }

    // Track retries
    if (!state.hasSlot(currentSlot)) {
      state.incrementRetry(currentSlot);
      if (state.getRetryCount(currentSlot) >= maxRetries) {
        final defaultVal = getDefaultForSlot(currentSlot);
        if (defaultVal != null) {
          state.updateSlots({currentSlot: defaultVal});
          state.resetRetry(currentSlot);
          return true;
        }
        return false; // Hard abort — required slot can't be filled
      }
      return false;
    }

    state.resetRetry(currentSlot);
    return true;
  }

  /// Apply skip/default for the current slot.
  bool skipCurrentSlot(BotIntentType intent, ConversationState state) {
    final slot = getNextSlot(intent, state);
    if (slot == null) return false;
    if (!_skippableSlots.contains(slot)) return false;

    final defaultVal = getDefaultForSlot(slot);
    if (defaultVal != null) {
      state.updateSlots({slot: defaultVal});
      state.resetRetry(slot);
      return true;
    }
    return false;
  }

  /// Get default value for a skippable slot.
  static String? getDefaultForSlot(String slot) {
    switch (slot) {
      case 'price_type': return 'Negotiable';
      case 'advance_percentage': return '80';
      case 'truck_type': return 'Any';
      case 'tyres': return 'any';
      case 'pickup_date':
        return DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String()
            .split('T')
            .first;
      case 'notes': return 'None';
      case 'search_truck_type': return 'Any';
      case 'search_material': return 'Any';
      default: return null;
    }
  }

  /// Check if a slot can be skipped.
  bool canSkip(String slot) => _skippableSlots.contains(slot);

  String _intentToTaskName(BotIntentType intent) {
    switch (intent) {
      case BotIntentType.postLoad: return 'post_load';
      case BotIntentType.findLoads: return 'find_loads';
      case BotIntentType.bookLoad: return 'book_load';
      case BotIntentType.superLoad: return 'super_load';
      case BotIntentType.navigateTo: return 'navigate';
      default: return 'post_load';
    }
  }

  void _tryRawInputForSlot(
      ConversationState state, String slot, String trimmed) {
    if (trimmed.isEmpty || trimmed.length >= 100) return;

    switch (slot) {
      case 'origin':
      case 'destination':
        final resolved = _entityExtractor.resolveCity(trimmed);
        if (resolved != null) {
          state.updateSlots({slot: resolved});
        } else if (trimmed.length >= 2) {
          final titleCased =
              trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
          state.updateSlots({slot: titleCased});
        }
        break;
      case 'material':
      case 'truck_type':
      case 'search_truck_type':
      case 'search_material':
        state.updateSlots({slot: trimmed});
        break;
      case 'weight':
        final weightMatch = RegExp(r'\d+(?:\.\d+)?').firstMatch(trimmed);
        if (weightMatch != null) {
          final val = double.tryParse(weightMatch.group(0)!);
          if (val != null && val > 0 && val <= 10000) {
            state.updateSlots({slot: weightMatch.group(0)!});
          }
        } else {
          final hindiVal = EntityExtractor.parseHindiNumber(trimmed);
          if (hindiVal != null && hindiVal > 0 && hindiVal <= 10000) {
            state.updateSlots({
              slot: hindiVal.toStringAsFixed(
                  hindiVal == hindiVal.roundToDouble() ? 0 : 1)
            });
          }
        }
        break;
      case 'price':
        final priceMatch = RegExp(r'\d+(?:\.\d+)?').firstMatch(trimmed);
        if (priceMatch != null) {
          final val = double.tryParse(priceMatch.group(0)!);
          if (val != null && val >= 100) {
            state.updateSlots({slot: priceMatch.group(0)!});
          }
        } else {
          final hindiVal = EntityExtractor.parseHindiNumber(trimmed);
          if (hindiVal != null && hindiVal >= 100) {
            state.updateSlots({
              slot: hindiVal.toStringAsFixed(
                  hindiVal == hindiVal.roundToDouble() ? 0 : 1)
            });
          }
        }
        break;
      case 'notes':
        final lt = trimmed.toLowerCase();
        if (lt == 'no' || lt == 'nahi' || lt == 'नहीं' || lt == 'none') {
          state.updateSlots({slot: 'None'});
        } else {
          state.updateSlots({slot: trimmed});
        }
        break;
      case 'advance_percentage':
        final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isNotEmpty) {
          final val = int.tryParse(digits);
          if (val != null && val >= 0 && val <= 100) {
            state.updateSlots({slot: digits});
          }
        }
        break;
      case 'pickup_date':
        final normalized = _normalizeDateInput(trimmed);
        if (normalized != null) {
          state.updateSlots({slot: normalized});
        }
        break;
      case 'price_type':
        final lt = trimmed.toLowerCase();
        if (lt.contains('negotiable') || lt.contains('nego') || lt.contains('mol')) {
          state.updateSlots({slot: 'Negotiable'});
        } else if (lt.contains('fixed') || lt.contains('fix') || lt.contains('pakka')) {
          state.updateSlots({slot: 'Fixed'});
        } else {
          state.updateSlots({slot: trimmed});
        }
        break;
      case 'tyres':
        const validTyres = {6, 10, 12, 14, 16, 18, 22};
        final tyreLt = trimmed.toLowerCase();
        if (tyreLt == 'any' || tyreLt == 'koi bhi') {
          state.updateSlots({slot: 'any'});
        } else {
          final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
          final tyreInt = int.tryParse(digits);
          if (tyreInt != null && validTyres.contains(tyreInt)) {
            state.updateSlots({slot: digits});
          } else if (tyreInt != null) {
            final nearest = validTyres.reduce((a, b) =>
                (a - tyreInt).abs() <= (b - tyreInt).abs() ? a : b);
            state.updateSlots({slot: nearest.toString()});
          }
        }
        break;
      case 'truck_count':
        final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isNotEmpty) {
          final val = int.tryParse(digits);
          if (val != null && val > 0 && val <= 100) {
            state.updateSlots({slot: digits});
          }
        }
        break;
      case 'payment_term':
        final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.isNotEmpty) {
          final val = int.tryParse(digits);
          if (val != null && val >= 2 && val <= 20) {
            state.updateSlots({slot: digits});
          }
        } else if (trimmed.toLowerCase().contains('2')) {
          state.updateSlots({slot: '2'});
        } else if (trimmed.toLowerCase().contains('10')) {
          state.updateSlots({slot: '10'});
        }
        break;
    }
  }

  String? _normalizeDateInput(String input) {
    final lower = input.toLowerCase().trim();
    final now = DateTime.now();

    if (lower == 'today' || lower == 'aaj' || lower == 'आज') {
      return now.toIso8601String().split('T').first;
    }
    if (lower == 'tomorrow' || lower == 'kal' || lower == 'कल') {
      return now.add(const Duration(days: 1)).toIso8601String().split('T').first;
    }
    if (lower == 'day after' || lower == 'day after tomorrow' ||
        lower == 'parso' || lower == 'परसों') {
      return now.add(const Duration(days: 2)).toIso8601String().split('T').first;
    }
    final inDays = RegExp(r'in (\d+) days?').firstMatch(lower);
    if (inDays != null) {
      final d = int.tryParse(inDays.group(1)!);
      if (d != null) {
        return now.add(Duration(days: d)).toIso8601String().split('T').first;
      }
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return input;
    final dmy = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$').firstMatch(input);
    if (dmy != null) {
      final d = dmy.group(1)!.padLeft(2, '0');
      final m = dmy.group(2)!.padLeft(2, '0');
      final y = dmy.group(3)!;
      return '$y-$m-$d';
    }
    return null;
  }

  String _fallbackSlotPrompt(String slot, String language, bool isRetry) {
    final isHi = language == 'hi';
    final retryPrefix = isRetry
        ? (isHi ? 'Samajh nahi aaya. ' : 'I didn\'t understand. ')
        : '';

    switch (slot) {
      case 'origin':
        return '$retryPrefix${isHi ? 'Kahan se load bhejna hai?' : 'Where is the pickup city?'}';
      case 'destination':
        return '$retryPrefix${isHi ? 'Kahan tak bhejna hai?' : 'Where should it be delivered?'}';
      case 'material':
        return '$retryPrefix${isHi ? 'Kya maal hai?' : 'What material?'}';
      case 'weight':
        return '$retryPrefix${isHi ? 'Kitna weight hai? (Tonnes mein)' : 'How much weight? (in tonnes)'}';
      case 'price':
        return '$retryPrefix${isHi ? 'Rate kya hai? (₹ per tonne)' : 'What rate per tonne? (in ₹)'}';
      case 'truck_type':
        return '$retryPrefix${isHi ? 'Kis type ka truck chahiye?' : 'What truck type?'}';
      case 'notes':
        return isHi
            ? 'Kuch aur batana hai? (Skip ke liye "nahi" bolein)'
            : 'Any additional notes? (Say "no" to skip)';
      default:
        return '$retryPrefix${isHi ? 'Please provide $slot' : 'Please provide $slot'}';
    }
  }
}
