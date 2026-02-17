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
  const truckerEmail = 'test-trucker@example.com';
  const truckerPassword = 'Tabish%%Khan721';
  const adminEmail = 'zaftyslogistics@gmail.com';
  const adminPassword = 'Tabish%%Khan721';

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

    final supplierAuth = await supplierClient.auth.signInWithPassword(
      email: supplierEmail,
      password: supplierPassword,
    );
    expect(supplierAuth.user, isNotNull,
        reason: 'Supplier runtime flow tests require supplier credentials.');
    supplierUser = supplierAuth.user!;

    final truckerAuth = await truckerClient.auth.signInWithPassword(
      email: truckerEmail,
      password: truckerPassword,
    );
    expect(truckerAuth.user, isNotNull,
        reason: 'Trucker runtime flow tests require trucker credentials.');
    truckerUser = truckerAuth.user!;

    final adminAuth = await adminClient.auth.signInWithPassword(
      email: adminEmail,
      password: adminPassword,
    );
    expect(adminAuth.user, isNotNull,
        reason: 'Admin credentials are required for queue visibility checks.');

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
        reason: 'Privileged bootstrap should seed supplier-trucker conversation fixture.');
  });

  tearDownAll(() async {
    await supplierClient.auth.signOut();
    await truckerClient.auth.signOut();
    await adminClient.auth.signOut();
  });

  test('Supplier onboarding rows are idempotent and verification payload persists',
      () async {
    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final companySuffix = marker.substring(marker.length - 6);

    await supplierDb.createSupplierData(supplierUser.id, {});
    await supplierDb.updateSupplierData(supplierUser.id, {
      'company_name': 'Runtime Supplier $companySuffix',
      'gst_number': 'GST$companySuffix',
      'business_licence_doc_url': 'verification-docs/${supplierUser.id}_biz.jpg',
    });

    await supplierDb.updateProfile(supplierUser.id, {
      'current_role': 'supplier',
      'verification_status': 'pending',
    });

    final profile = await supplierDb.getUserProfile(supplierUser.id);
    final supplier = await supplierDb.getSupplierData(supplierUser.id);

    expect(profile, isNotNull);
    expect(profile!['verification_status'], 'pending');
    expect(profile['current_role'], 'supplier');

    expect(supplier, isNotNull);
    expect((supplier!['company_name'] as String).contains('Runtime Supplier'), isTrue);

  });

  test('Pending supplier verification is visible to admin queue query', () async {
    final pending = await adminClient
        .from('profiles')
        .select('id, current_role, verification_status')
        .eq('id', supplierUser.id)
        .eq('current_role', 'supplier')
        .eq('verification_status', 'pending')
        .maybeSingle();

    expect(
      pending,
      isNotNull,
      reason:
          'Supplier verification submission should be visible to admin pending-queue query.',
    );
  });

  test('Trucker load-search query + chat create/send flow works', () async {
    await truckerDb.createTruckerData(truckerUser.id, {});

    final activeLoads = await truckerDb.getActiveLoads(
      originCity: '',
      destCity: '',
      truckType: 'Any',
      sortOrder: 'none',
      verifiedOnly: false,
    );
    expect(activeLoads, isA<List<Map<String, dynamic>>>());

    final existingConversation = await truckerDb.getConversationById(seededConversationId!);
    expect(existingConversation, isNotNull,
        reason: 'Seeded conversation should be visible to trucker before sending message.');

    final marker = 'runtime-trucker-location-${DateTime.now().millisecondsSinceEpoch}';
    final sent = await truckerDb.sendMessage(
      conversationId: seededConversationId!,
      senderId: truckerUser.id,
      type: 'location',
      text: marker,
      payload: const {'lat': 19.0760, 'lng': 72.8777},
    );

    expect(sent['message_type'], 'location');

    final supplierMessages = await supplierDb.getMessages(seededConversationId!);
    expect(
      supplierMessages.any((m) => m['text_content'] == marker),
      isTrue,
      reason: 'Supplier should receive the trucker chat message in same conversation.',
    );
  });
}
