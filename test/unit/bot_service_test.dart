import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/features/bot/services/basic_bot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences to avoid MissingPluginException
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        if (methodCall.method == 'remove') return true;
        if (methodCall.method == 'setString') return true;
        return null;
      },
    );
  });

  late BasicBotService botService;

  setUpAll(() async {
    botService = BasicBotService();
    await botService.initialize();
  });

  group('BasicBotService context greeting', () {
    test('English greeting includes bot name', () {
      final greeting = botService.getContextGreeting(language: 'en');
      expect(greeting, contains('Nancy'));
      expect(greeting.toLowerCase(), anyOf(contains('load'), contains('help')));
    });

    test('Hindi greeting includes bot name', () {
      final greeting = botService.getContextGreeting(language: 'hi');
      expect(greeting, contains('Nancy'));
    });

    test('includes active loads count when > 0', () {
      final greeting = botService.getContextGreeting(
        language: 'en',
        activeLoadsCount: 3,
      );
      expect(greeting, contains('3 active loads'));
    });

    test('includes active trips count when > 0', () {
      final greeting = botService.getContextGreeting(
        language: 'en',
        activeTripsCount: 2,
      );
      expect(greeting, contains('2 active trips'));
    });

    test('includes verification status when not verified', () {
      final greeting = botService.getContextGreeting(
        language: 'en',
        verificationStatus: 'pending',
      );
      expect(greeting, contains('Verification: pending'));
    });

    test('excludes verification when verified', () {
      final greeting = botService.getContextGreeting(
        language: 'en',
        verificationStatus: 'verified',
      );
      expect(greeting, isNot(contains('Verification')));
    });
  });

  group('BasicBotService processMessage — intent classification', () {
    test('"post load" triggers postLoad flow for supplier', () async {
      botService.resetConversation('test-user');
      final response = await botService.processMessage(
        userId: 'test-user',
        message: 'I want to post a load',
        language: 'en',
        userRole: 'supplier',
      );
      // Should respond with something (either asking for slot or confirming intent)
      expect(response.text, isNotEmpty);
    });

    test('"find loads" triggers findLoads flow for trucker', () async {
      botService.resetConversation('test-user-2');
      final response = await botService.processMessage(
        userId: 'test-user-2',
        message: 'find loads',
        language: 'en',
        userRole: 'trucker',
      );
      expect(response.text, isNotEmpty);
    });

    test('"hello" returns greeting with suggestions', () async {
      botService.resetConversation('test-user-3');
      final response = await botService.processMessage(
        userId: 'test-user-3',
        message: 'hello',
        language: 'en',
      );
      expect(response.text, isNotEmpty);
      expect(response.suggestions, isNotNull);
    });

    test('"thanks" returns non-empty response', () async {
      botService.resetConversation('test-user-4');
      final response = await botService.processMessage(
        userId: 'test-user-4',
        message: 'thank you',
        language: 'en',
      );
      expect(response.text, isNotEmpty);
    });
  });

  group('BasicBotService — role gating', () {
    test('trucker cannot post load', () async {
      botService.resetConversation('trucker-1');
      final response = await botService.processMessage(
        userId: 'trucker-1',
        message: 'post a load',
        language: 'en',
        userRole: 'trucker',
      );
      expect(response.text.toLowerCase(), anyOf(
        contains("can't post"),
        contains('cannot post'),
        contains('नहीं कर सकते'),
        contains('find loads'),
      ));
    });

    test('supplier cannot find loads', () async {
      botService.resetConversation('supplier-1');
      final response = await botService.processMessage(
        userId: 'supplier-1',
        message: 'find loads near me',
        language: 'en',
        userRole: 'supplier',
      );
      expect(response.text.toLowerCase(), anyOf(
        contains("don't search"),
        contains('cannot search'),
        contains('post a load'),
        contains('नहीं खोजते'),
      ));
    });
  });

  group('BasicBotService — cancel and reset', () {
    test('"cancel" resets conversation', () async {
      botService.resetConversation('cancel-user');
      // Start a flow
      await botService.processMessage(
        userId: 'cancel-user',
        message: 'post load',
        language: 'en',
        userRole: 'supplier',
      );
      // Cancel it
      final response = await botService.processMessage(
        userId: 'cancel-user',
        message: 'cancel',
        language: 'en',
        userRole: 'supplier',
      );
      expect(response.suggestions, isNotNull);
    });

    test('"reset" resets conversation', () async {
      botService.resetConversation('reset-user');
      await botService.processMessage(
        userId: 'reset-user',
        message: 'post load',
        language: 'en',
        userRole: 'supplier',
      );
      final response = await botService.processMessage(
        userId: 'reset-user',
        message: 'reset',
        language: 'en',
        userRole: 'supplier',
      );
      expect(response.suggestions, isNotNull);
    });
  });

  group('BasicBotService — slot filling', () {
    test('sequential slot prompts for postLoad', () async {
      botService.resetConversation('slot-user');

      // 1. Trigger postLoad with origin city
      final r1 = await botService.processMessage(
        userId: 'slot-user',
        message: 'post load from mumbai',
        language: 'en',
        userRole: 'supplier',
      );
      // Should respond with next prompt
      expect(r1.text, isNotEmpty);

      // 2. Provide destination
      final r2 = await botService.processMessage(
        userId: 'slot-user',
        message: 'pune',
        language: 'en',
        userRole: 'supplier',
      );
      // Should continue slot filling
      expect(r2.text, isNotEmpty);
      // Each response should be different (progressing through slots)
      expect(r2.text, isNot(equals(r1.text)));
    });
  });

  group('BasicBotService — correction detection', () {
    test('"nahi" during slot filling produces a response', () async {
      botService.resetConversation('correct-user');
      await botService.processMessage(
        userId: 'correct-user',
        message: 'post load from mumbai to pune',
        language: 'en',
        userRole: 'supplier',
      );
      final response = await botService.processMessage(
        userId: 'correct-user',
        message: 'nahi',
        language: 'en',
        userRole: 'supplier',
      );
      expect(response.text, isNotEmpty);
    });

    test('"wrong" during slot filling produces a response', () async {
      botService.resetConversation('wrong-user');
      await botService.processMessage(
        userId: 'wrong-user',
        message: 'post load from delhi',
        language: 'en',
        userRole: 'supplier',
      );
      final response = await botService.processMessage(
        userId: 'wrong-user',
        message: 'wrong',
        language: 'en',
        userRole: 'supplier',
      );
      expect(response.text, isNotEmpty);
    });
  });

  group('BasicBotService — fallback', () {
    test('unrecognized input returns a non-empty response for supplier', () async {
      botService.resetConversation('fallback-sup');
      final response = await botService.processMessage(
        userId: 'fallback-sup',
        message: 'asdkjhqwekjhzxcv random gibberish 12345',
        language: 'en',
        userRole: 'supplier',
      );
      // Bot should always respond with something useful
      expect(response.text, isNotEmpty);
    });

    test('unrecognized input returns a non-empty response for trucker', () async {
      botService.resetConversation('fallback-trk');
      final response = await botService.processMessage(
        userId: 'fallback-trk',
        message: 'asdkjhqwekjhzxcv random gibberish 12345',
        language: 'en',
        userRole: 'trucker',
      );
      expect(response.text, isNotEmpty);
    });
  });

  group('BasicBotService — conversation management', () {
    test('resetConversation clears state', () {
      botService.resetConversation('mgmt-user');
      final history = botService.getConversationHistory('mgmt-user');
      expect(history, isNull);
    });

    test('history accumulates across messages', () async {
      botService.resetConversation('hist-user');
      await botService.processMessage(
        userId: 'hist-user',
        message: 'hello',
        language: 'en',
      );
      final history = botService.getConversationHistory('hist-user');
      expect(history, isNotNull);
      // Should have user message + bot response = 2
      expect(history!.length, 2);
      expect(history[0].isUser, true);
      expect(history[1].isUser, false);
    });
  });
}
