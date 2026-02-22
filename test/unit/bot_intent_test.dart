import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/features/bot/models/bot_intent.dart';
import 'package:tranzfort/src/features/bot/models/bot_response.dart';

void main() {
  group('BotIntent', () {
    test('isHighConfidence true at 0.5 and above', () {
      expect(BotIntent(type: BotIntentType.postLoad, confidence: 0.5).isHighConfidence, true);
      expect(BotIntent(type: BotIntentType.postLoad, confidence: 0.7).isHighConfidence, true);
      expect(BotIntent(type: BotIntentType.postLoad, confidence: 1.0).isHighConfidence, true);
    });

    test('isHighConfidence false below 0.5', () {
      expect(BotIntent(type: BotIntentType.postLoad, confidence: 0.49).isHighConfidence, false);
      expect(BotIntent(type: BotIntentType.postLoad, confidence: 0.3).isHighConfidence, false);
      expect(BotIntent(type: BotIntentType.postLoad, confidence: 0.0).isHighConfidence, false);
    });
  });

  group('Slot', () {
    test('isFilled true when value non-null non-empty', () {
      expect(Slot(name: 'origin', value: 'Mumbai').isFilled, true);
    });

    test('isFilled false when null or empty', () {
      expect(Slot(name: 'origin').isFilled, false);
      expect(Slot(name: 'origin', value: null).isFilled, false);
      expect(Slot(name: 'origin', value: '').isFilled, false);
    });
  });

  group('BotMessage serialization', () {
    test('toJson/fromJson round-trip for user message', () {
      final msg = BotMessage(text: 'Hello', isUser: true);
      final json = msg.toJson();
      final restored = BotMessage.fromJson(json);
      expect(restored.text, 'Hello');
      expect(restored.isUser, true);
      expect(restored.suggestions, isNull);
      expect(restored.actions, isNull);
    });

    test('toJson/fromJson round-trip for bot message with suggestions', () {
      final msg = BotMessage(
        text: 'How can I help?',
        isUser: false,
        suggestions: ['Post Load', 'Find Loads'],
      );
      final json = msg.toJson();
      final restored = BotMessage.fromJson(json);
      expect(restored.text, 'How can I help?');
      expect(restored.isUser, false);
      expect(restored.suggestions, ['Post Load', 'Find Loads']);
    });

    test('toJson/fromJson round-trip for bot message with actions', () {
      final msg = BotMessage(
        text: 'Navigate',
        isUser: false,
        actions: [
          BotAction(label: 'Go', value: 'navigate', payload: {'route': '/nav'}),
        ],
      );
      final json = msg.toJson();
      final restored = BotMessage.fromJson(json);
      expect(restored.actions, isNotNull);
      expect(restored.actions!.length, 1);
      expect(restored.actions![0].label, 'Go');
      expect(restored.actions![0].value, 'navigate');
      expect(restored.actions![0].payload?['route'], '/nav');
    });
  });

  group('BotIntentType enum', () {
    test('all expected intent types exist', () {
      final types = BotIntentType.values.map((e) => e.name).toSet();
      expect(types, contains('postLoad'));
      expect(types, contains('findLoads'));
      expect(types, contains('myLoads'));
      expect(types, contains('myTrips'));
      expect(types, contains('checkStatus'));
      expect(types, contains('repeatLoad'));
      expect(types, contains('navigateTo'));
      expect(types, contains('faqHowToPost'));
      expect(types, contains('faqHowToVerify'));
      expect(types, contains('faqPricing'));
      expect(types, contains('faqSupport'));
      expect(types, contains('manageFleet'));
      expect(types, contains('greeting'));
      expect(types, contains('thanks'));
      expect(types, contains('fallback'));
    });
  });
}
