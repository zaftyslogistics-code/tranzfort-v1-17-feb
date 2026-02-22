// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/src/core/services/database_service.dart';

void main() {
  const supabaseUrl = 'https://fjixgerqwftvkhrkfjbt.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqaXhnZXJxd2Z0dmtocmtmamJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDA2NTgsImV4cCI6MjA4NTUxNjY1OH0.ogamClsIOa2exygt8j61bPKcHTPsj3vQXRitw_KcmNs';
  const supplierEmail = 'martechengine@gmail.com';
  const supplierPassword = 'Tabish%%Khan721';

  late SupabaseClient client;
  late DatabaseService db;
  late User user;

  setUpAll(() async {
    client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    db = DatabaseService(client);

    final auth = await client.auth.signInWithPassword(
      email: supplierEmail, password: supplierPassword,
    );
    expect(auth.user, isNotNull);
    user = auth.user!;
  });

  tearDownAll(() async {
    await client.auth.signOut();
  });

  test('Create ticket → appears in getMyTickets', () async {
    final subject = 'Runtime ticket ${DateTime.now().millisecondsSinceEpoch}';
    await db.createTicket(
      userId: user.id,
      subject: subject,
      description: 'Automated test ticket',
    );

    final tickets = await db.getMyTickets(user.id);
    final found = tickets.any((t) => t['subject'] == subject);
    expect(found, isTrue, reason: 'Created ticket should appear in my tickets');
  });

  test('Add ticket message → appears in getTicketMessages', () async {
    final subject = 'Msg ticket ${DateTime.now().millisecondsSinceEpoch}';
    await db.createTicket(
      userId: user.id,
      subject: subject,
      description: 'Ticket for message test',
    );

    final tickets = await db.getMyTickets(user.id);
    final ticket = tickets.firstWhere((t) => t['subject'] == subject);
    final ticketId = ticket['id'] as String;

    final marker = 'runtime-msg-${DateTime.now().millisecondsSinceEpoch}';
    await db.addTicketMessage(
      ticketId: ticketId,
      senderId: user.id,
      message: marker,
    );

    final messages = await db.getTicketMessages(ticketId);
    final found = messages.any((m) => (m['message'] as String?) == marker);
    expect(found, isTrue, reason: 'Added message should appear in ticket messages');
  });

  test('Ticket detail retrieval', () async {
    final tickets = await db.getMyTickets(user.id);
    expect(tickets, isNotEmpty);

    final ticketId = tickets.first['id'] as String;
    final detail = await db.getTicketById(ticketId);
    expect(detail, isNotNull);
    expect(detail!['id'], ticketId);
    expect(detail['user_id'], user.id);
  });
}
