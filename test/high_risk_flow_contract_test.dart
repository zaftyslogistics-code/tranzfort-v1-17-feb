import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('High-risk user flow contracts', () {
    test('Chat service persists to messages relation with explicit message_type', () {
      final source = File('lib/src/core/services/database_service.dart').readAsStringSync();

      expect(source, contains(".from('messages')"));
      expect(source, contains("'message_type': type"));
      expect(source, contains("table: 'messages'"));
    });

    test('Support ticket message APIs use support_ticket_messages relation', () {
      final source = File('lib/src/core/services/database_service.dart').readAsStringSync();

      expect(source, contains(".from('support_ticket_messages')"));
      expect(source, isNot(contains(".from('ticket_messages')")));
    });

    test('Schema smoke checks guard critical user relations', () {
      final source = File('lib/src/core/services/schema_smoke_check_service.dart').readAsStringSync();

      expect(source, contains("'public_profiles'"));
      expect(source, contains("'conversations'"));
      expect(source, contains("'messages'"));
      expect(source, contains("'support_ticket_messages'"));
    });
  });
}
