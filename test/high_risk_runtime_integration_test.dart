// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/src/core/services/database_service.dart';

void main() {
  const supabaseUrl = 'https://fjixgerqwftvkhrkfjbt.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqaXhnZXJxd2Z0dmtocmtmamJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDA2NTgsImV4cCI6MjA4NTUxNjY1OH0.ogamClsIOa2exygt8j61bPKcHTPsj3vQXRitw_KcmNs';
  const supplierEmail = 'test-supplier@example.com';
  const supplierPassword = 'Tabish%%Khan721';
  const adminEmail = 'zaftyslogistics@gmail.com';
  const adminPassword = 'Tabish%%Khan721';

  late SupabaseClient client;
  late SupabaseClient adminClient;
  late DatabaseService databaseService;
  late User supplierUser;
  String? seededConversationId;

  setUpAll(() async {
    client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    adminClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    databaseService = DatabaseService(client);

    final auth = await client.auth.signInWithPassword(
      email: supplierEmail,
      password: supplierPassword,
    );
    expect(auth.user, isNotNull, reason: 'Supplier sign-in must succeed for runtime tests.');
    supplierUser = auth.user!;

    final adminAuth = await adminClient.auth.signInWithPassword(
      email: adminEmail,
      password: adminPassword,
    );
    expect(adminAuth.user, isNotNull, reason: 'Admin sign-in should work for runtime fixture lookup.');

    final bootstrap = await adminClient.rpc(
      'test_bootstrap_user_chat_fixture',
      params: {'p_supplier_id': supplierUser.id},
    );

    if (bootstrap is List && bootstrap.isNotEmpty) {
      seededConversationId =
          (bootstrap.first as Map<String, dynamic>)['conversation_id'] as String;
    } else if (bootstrap is Map<String, dynamic>) {
      seededConversationId = bootstrap['conversation_id'] as String;
    }

    expect(
      seededConversationId,
      isNotNull,
      reason: 'Privileged chat fixture bootstrap must return a seeded conversation id.',
    );
  });

  tearDownAll(() async {
    await client.auth.signOut();
    await adminClient.auth.signOut();
  });

  test('User can send non-text (location) chat message when conversation exists', () async {
    final marker = 'runtime-location-${DateTime.now().millisecondsSinceEpoch}';

    final inserted = await databaseService.sendMessage(
      conversationId: seededConversationId!,
      senderId: supplierUser.id,
      type: 'location',
      text: marker,
      payload: const {'lat': 19.0760, 'lng': 72.8777},
    );

    expect(inserted['message_type'], 'location');
    expect(inserted['text_content'], marker);
  });

  test('User can create ticket and append ticket message', () async {
    final subject = 'Runtime ticket ${DateTime.now().millisecondsSinceEpoch}';

    await databaseService.createTicket(
      userId: supplierUser.id,
      subject: subject,
      description: 'Runtime integration verification ticket',
    );

    final myTickets = await databaseService.getMyTickets(supplierUser.id);
    final created = myTickets.cast<Map<String, dynamic>?>().firstWhere(
          (ticket) => ticket?['subject'] == subject,
          orElse: () => null,
        );

    expect(created, isNotNull, reason: 'Created ticket should be retrievable in my tickets list.');

    final ticketId = created!['id'] as String;
    final marker = 'runtime-ticket-msg-${DateTime.now().millisecondsSinceEpoch}';

    await databaseService.addTicketMessage(
      ticketId: ticketId,
      senderId: supplierUser.id,
      message: marker,
    );

    final messages = await databaseService.getTicketMessages(ticketId);
    expect(
      messages.any((message) => (message['message'] as String?) == marker),
      isTrue,
      reason: 'Newly added ticket message should be retrievable from ticket thread.',
    );
  });
}
