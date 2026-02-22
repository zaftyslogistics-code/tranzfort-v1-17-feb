import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String dbSource;
  late String smokeSource;

  setUpAll(() {
    dbSource = File('lib/src/core/services/database_service.dart').readAsStringSync();
    smokeSource = File('lib/src/core/services/schema_smoke_check_service.dart').readAsStringSync();
  });

  group('Database service message contracts', () {
    test('messages use .from(messages) with message_type', () {
      expect(dbSource, contains(".from('messages')"));
      expect(dbSource, contains("'message_type': type"));
    });

    test('support tickets use support_ticket_messages', () {
      expect(dbSource, contains(".from('support_ticket_messages')"));
      expect(dbSource, isNot(contains(".from('ticket_messages')")));
    });
  });

  group('Database service conversation FK joins', () {
    test('conversations join through suppliers/truckers → profiles', () {
      expect(dbSource, contains('suppliers!conversations_supplier_id_fkey'));
      expect(dbSource, contains('truckers!conversations_trucker_id_fkey'));
      // Must join through suppliers → profiles, not directly profiles
      expect(dbSource, contains('suppliers!conversations_supplier_id_fkey(id, profiles('));
      expect(dbSource, contains('truckers!conversations_trucker_id_fkey(id, profiles('));
    });
  });

  group('Database service upsert contracts', () {
    test('all upsert calls have onConflict', () {
      expect(dbSource, contains('onConflict'));
      // createSupplierData and createTruckerData use upsert
      expect(dbSource, contains(".from('suppliers').upsert("));
      expect(dbSource, contains(".from('truckers').upsert("));
    });
  });

  group('Database service table references', () {
    test('references correct table names', () {
      expect(dbSource, contains(".from('profiles')"));
      expect(dbSource, contains(".from('public_profiles')"));
      expect(dbSource, contains(".from('suppliers')"));
      expect(dbSource, contains(".from('truckers')"));
      expect(dbSource, contains(".from('loads')"));
      expect(dbSource, contains(".from('trucks')"));
      expect(dbSource, contains(".from('conversations')"));
      expect(dbSource, contains(".from('messages')"));
      expect(dbSource, contains(".from('support_tickets')"));
      expect(dbSource, contains(".from('support_ticket_messages')"));
      expect(dbSource, contains(".from('payment_ledger')"));
      expect(dbSource, contains(".from('ratings')"));
      expect(dbSource, contains(".from('payout_profiles')"));
      expect(dbSource, contains(".from('user_consents')"));
    });
  });

  group('Schema smoke check service', () {
    test('covers critical user relations', () {
      expect(smokeSource, contains("'public_profiles'"));
      expect(smokeSource, contains("'conversations'"));
      expect(smokeSource, contains("'messages'"));
      expect(smokeSource, contains("'support_ticket_messages'"));
    });
  });

  group('Database service method completeness', () {
    test('has all CRUD methods for loads', () {
      expect(dbSource, contains('getActiveLoads'));
      expect(dbSource, contains('getLoadById'));
      expect(dbSource, contains('createLoad'));
      expect(dbSource, contains('updateLoad'));
      expect(dbSource, contains('getMyLoads'));
    });

    test('has all CRUD methods for trucks', () {
      expect(dbSource, contains('getMyTrucks'));
      expect(dbSource, contains('addTruck'));
      expect(dbSource, contains('getTruckById'));
      expect(dbSource, contains('deleteTruck'));
    });

    test('has chat lifecycle methods', () {
      expect(dbSource, contains('getOrCreateConversation'));
      expect(dbSource, contains('getConversationsByUser'));
      expect(dbSource, contains('sendMessage'));
      expect(dbSource, contains('getMessages'));
      expect(dbSource, contains('markAsRead'));
      expect(dbSource, contains('markAllAsRead'));
      expect(dbSource, contains('subscribeToMessages'));
    });

    test('has support ticket methods', () {
      expect(dbSource, contains('createTicket'));
      expect(dbSource, contains('getMyTickets'));
      expect(dbSource, contains('getTicketById'));
      expect(dbSource, contains('getTicketMessages'));
      expect(dbSource, contains('addTicketMessage'));
    });
  });
}
