import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/features/bot/models/bot_intent.dart';
import 'package:tranzfort/src/features/bot/models/bot_response.dart';
import 'package:tranzfort/src/features/bot/models/conversation_state.dart';

void main() {
  group('ConversationState.updateSlots', () {
    test('sets values correctly', () {
      final state = ConversationState();
      state.updateSlots({'origin': 'Mumbai', 'destination': 'Pune'});
      expect(state.getSlot('origin'), 'Mumbai');
      expect(state.getSlot('destination'), 'Pune');
    });

    test('ignores null and empty values', () {
      final state = ConversationState();
      state.updateSlots({'origin': null, 'destination': ''});
      expect(state.hasSlot('origin'), false);
      expect(state.hasSlot('destination'), false);
    });

    test('overwrites existing values', () {
      final state = ConversationState();
      state.updateSlots({'origin': 'Mumbai'});
      state.updateSlots({'origin': 'Delhi'});
      expect(state.getSlot('origin'), 'Delhi');
    });
  });

  group('ConversationState.hasSlot', () {
    test('true when filled', () {
      final state = ConversationState();
      state.updateSlots({'origin': 'Mumbai'});
      expect(state.hasSlot('origin'), true);
    });

    test('false when empty or missing', () {
      final state = ConversationState();
      expect(state.hasSlot('origin'), false);
      state.updateSlots({'origin': ''});
      expect(state.hasSlot('origin'), false);
    });
  });

  group('ConversationState.clearSlot', () {
    test('removes specific slot', () {
      final state = ConversationState();
      state.updateSlots({'origin': 'Mumbai', 'destination': 'Pune'});
      state.clearSlot('origin');
      expect(state.hasSlot('origin'), false);
      expect(state.hasSlot('destination'), true);
    });
  });

  group('ConversationState.clearLastSlot', () {
    test('removes in reverse fill order for postLoad', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.postLoad);
      state.updateSlots({
        'origin': 'Mumbai',
        'destination': 'Pune',
        'material': 'Steel',
      });
      // clearLastSlot should remove 'material' first (last in fill order)
      final cleared = state.clearLastSlot();
      expect(cleared, 'material');
      expect(state.hasSlot('material'), false);
      expect(state.hasSlot('destination'), true);
    });

    test('removes in reverse fill order for findLoads', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.findLoads);
      state.updateSlots({'origin': 'Mumbai', 'destination': 'Pune'});
      final cleared = state.clearLastSlot();
      expect(cleared, 'destination');
      expect(state.hasSlot('origin'), true);
    });

    test('returns null when no slots filled', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.postLoad);
      expect(state.clearLastSlot(), isNull);
    });
  });

  group('ConversationState.currentSlotBeingFilled', () {
    test('returns first empty slot for postLoad', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.postLoad);
      expect(state.currentSlotBeingFilled, 'origin');

      state.updateSlots({'origin': 'Mumbai'});
      expect(state.currentSlotBeingFilled, 'destination');

      state.updateSlots({'destination': 'Pune'});
      expect(state.currentSlotBeingFilled, 'material');
    });

    test('returns first empty slot for findLoads', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.findLoads);
      expect(state.currentSlotBeingFilled, 'origin');

      state.updateSlots({'origin': 'Mumbai'});
      expect(state.currentSlotBeingFilled, 'destination');

      state.updateSlots({'destination': 'Pune'});
      expect(state.currentSlotBeingFilled, 'search_truck_type');
    });

    test('returns null when no active intent', () {
      final state = ConversationState();
      expect(state.currentSlotBeingFilled, isNull);
    });
  });

  group('ConversationState.hasAllRequiredSlots', () {
    test('postLoad needs all 10 slots', () {
      final state = ConversationState();
      expect(state.hasAllRequiredSlots(BotIntentType.postLoad), false);

      state.updateSlots({
        'origin': 'Mumbai',
        'destination': 'Pune',
        'material': 'Steel',
        'weight': '25',
        'price': '3000',
        'price_type': 'Fixed',
        'advance_percentage': '20',
        'truck_type': 'Open',
        'pickup_date': '2026-03-01',
        'notes': 'Handle with care',
      });
      expect(state.hasAllRequiredSlots(BotIntentType.postLoad), true);
    });

    test('findLoads needs origin OR destination', () {
      final state = ConversationState();
      expect(state.hasAllRequiredSlots(BotIntentType.findLoads), false);

      state.updateSlots({'origin': 'Mumbai'});
      expect(state.hasAllRequiredSlots(BotIntentType.findLoads), true);
    });

    test('other intents always return true', () {
      final state = ConversationState();
      expect(state.hasAllRequiredSlots(BotIntentType.greeting), true);
      expect(state.hasAllRequiredSlots(BotIntentType.fallback), true);
    });
  });

  group('ConversationState.reset', () {
    test('clears everything', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.postLoad);
      state.updateSlots({'origin': 'Mumbai'});
      state.confirmationShown = true;
      state.incrementRetry('origin');

      state.reset();

      expect(state.activeIntent, isNull);
      expect(state.hasSlot('origin'), false);
      expect(state.confirmationShown, false);
      expect(state.getRetryCount('origin'), 0);
    });
  });

  group('ConversationState serialization', () {
    test('serialize/deserialize round-trip', () {
      final state = ConversationState();
      state.setActiveIntent(BotIntentType.postLoad);
      state.updateSlots({'origin': 'Mumbai', 'destination': 'Pune'});
      state.confirmationShown = true;
      state.addMessage(BotMessage(text: 'Hello', isUser: true));
      state.addMessage(BotMessage(text: 'Hi!', isUser: false));

      final json = state.serialize();
      final restored = ConversationState.deserialize(json);

      expect(restored.activeIntent, BotIntentType.postLoad);
      expect(restored.getSlot('origin'), 'Mumbai');
      expect(restored.getSlot('destination'), 'Pune');
      expect(restored.confirmationShown, true);
      expect(restored.history.length, 2);
      expect(restored.history[0].text, 'Hello');
      expect(restored.history[0].isUser, true);
      expect(restored.history[1].text, 'Hi!');
      expect(restored.history[1].isUser, false);
    });

    test('deserialize handles corrupt JSON gracefully', () {
      final state = ConversationState.deserialize('not valid json');
      expect(state.activeIntent, isNull);
      expect(state.history, isEmpty);
    });

    test('deserialize handles empty string', () {
      final state = ConversationState.deserialize('');
      expect(state.activeIntent, isNull);
    });
  });

  group('ConversationState retry count', () {
    test('increment, get, reset', () {
      final state = ConversationState();
      expect(state.getRetryCount('origin'), 0);

      state.incrementRetry('origin');
      expect(state.getRetryCount('origin'), 1);

      state.incrementRetry('origin');
      state.incrementRetry('origin');
      expect(state.getRetryCount('origin'), 3);

      state.resetRetry('origin');
      expect(state.getRetryCount('origin'), 0);
    });
  });

  group('ConversationState history', () {
    test('addMessage appends to history', () {
      final state = ConversationState();
      state.addMessage(BotMessage(text: 'msg1', isUser: true));
      state.addMessage(BotMessage(text: 'msg2', isUser: false));
      expect(state.history.length, 2);
      expect(state.history[0].text, 'msg1');
      expect(state.history[1].text, 'msg2');
    });
  });
}
