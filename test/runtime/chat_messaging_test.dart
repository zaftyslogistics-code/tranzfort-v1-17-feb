// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/src/core/services/database_service.dart';

void main() {
  const supabaseUrl = 'https://fjixgerqwftvkhrkfjbt.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqaXhnZXJxd2Z0dmtocmtmamJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDA2NTgsImV4cCI6MjA4NTUxNjY1OH0.ogamClsIOa2exygt8j61bPKcHTPsj3vQXRitw_KcmNs';
  // Real verified accounts
  const supplierEmail = 'martechengine@gmail.com';
  const truckerEmail = 'info.tabish.khan@gmail.com';
  const adminEmail = 'zaftyslogistics@gmail.com';
  const password = 'Tabish%%Khan721';

  late SupabaseClient supplierClient;
  late SupabaseClient truckerClient;
  late SupabaseClient adminClient;
  late DatabaseService supplierDb;
  late DatabaseService truckerDb;
  late User supplierUser;
  late User truckerUser;
  String? seededConversationId;

  setUpAll(() async {
    supplierClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    truckerClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    adminClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    supplierDb = DatabaseService(supplierClient);
    truckerDb = DatabaseService(truckerClient);

    final sAuth = await supplierClient.auth.signInWithPassword(
      email: supplierEmail, password: password,
    );
    supplierUser = sAuth.user!;

    final tAuth = await truckerClient.auth.signInWithPassword(
      email: truckerEmail, password: password,
    );
    truckerUser = tAuth.user!;

    await adminClient.auth.signInWithPassword(
      email: adminEmail, password: password,
    );

    // Bootstrap a conversation fixture
    final bootstrap = await adminClient.rpc(
      'test_bootstrap_user_chat_fixture',
      params: {
        'p_supplier_id': supplierUser.id,
        'p_trucker_id': truckerUser.id,
      },
    );
    if (bootstrap is List && bootstrap.isNotEmpty) {
      seededConversationId =
          (bootstrap.first as Map<String, dynamic>)['conversation_id'] as String;
    } else if (bootstrap is Map<String, dynamic>) {
      seededConversationId = bootstrap['conversation_id'] as String;
    }
    expect(seededConversationId, isNotNull,
        reason: 'Chat fixture bootstrap must return a conversation id.');
  });

  tearDownAll(() async {
    await supplierClient.auth.signOut();
    await truckerClient.auth.signOut();
    await adminClient.auth.signOut();
  });

  test('sendMessage — text type persists', () async {
    final marker = 'runtime-text-${DateTime.now().millisecondsSinceEpoch}';
    final sent = await supplierDb.sendMessage(
      conversationId: seededConversationId!,
      senderId: supplierUser.id,
      type: 'text',
      text: marker,
    );
    expect(sent['message_type'], 'text');
    expect(sent['text_content'], marker);
    expect(sent['conversation_id'], seededConversationId);
  });

  test('sendMessage — location type with payload', () async {
    final marker = 'runtime-loc-${DateTime.now().millisecondsSinceEpoch}';
    final sent = await truckerDb.sendMessage(
      conversationId: seededConversationId!,
      senderId: truckerUser.id,
      type: 'location',
      text: marker,
      payload: const {'lat': 19.0760, 'lng': 72.8777},
    );
    expect(sent['message_type'], 'location');
    expect(sent['text_content'], marker);
  });

  test('getMessages — returns messages in order', () async {
    final messages = await supplierDb.getMessages(seededConversationId!);
    expect(messages, isNotEmpty);
    // Messages should be in chronological order (oldest first)
    for (int i = 1; i < messages.length; i++) {
      final prev = DateTime.parse(messages[i - 1]['created_at'] as String);
      final curr = DateTime.parse(messages[i]['created_at'] as String);
      expect(curr.isAfter(prev) || curr.isAtSameMomentAs(prev), isTrue,
          reason: 'Messages should be in chronological order');
    }
  });

  test('Cross-user visibility: both parties see messages', () async {
    final marker = 'cross-vis-${DateTime.now().millisecondsSinceEpoch}';
    await supplierDb.sendMessage(
      conversationId: seededConversationId!,
      senderId: supplierUser.id,
      type: 'text',
      text: marker,
    );

    final truckerMessages = await truckerDb.getMessages(seededConversationId!);
    final found = truckerMessages.any((m) => m['text_content'] == marker);
    expect(found, isTrue,
        reason: 'Trucker should see supplier message in same conversation');
  });

  test('markAllAsRead — updates is_read for other party messages', () async {
    // Send a message as trucker
    final marker = 'read-test-${DateTime.now().millisecondsSinceEpoch}';
    await truckerDb.sendMessage(
      conversationId: seededConversationId!,
      senderId: truckerUser.id,
      type: 'text',
      text: marker,
    );

    // Mark all as read from supplier's perspective
    await supplierDb.markAllAsRead(seededConversationId!, supplierUser.id);

    // Verify — get messages and check the trucker's message is read
    final messages = await supplierDb.getMessages(seededConversationId!);
    final truckerMessages = messages.where(
      (m) => m['sender_id'] == truckerUser.id,
    );
    for (final msg in truckerMessages) {
      expect(msg['is_read'], isTrue,
          reason: 'Trucker messages should be marked as read by supplier');
    }
  });

  test('getConversationById returns seeded conversation', () async {
    final conv = await supplierDb.getConversationById(seededConversationId!);
    expect(conv, isNotNull);
    expect(conv!['id'], seededConversationId);
  });
}
