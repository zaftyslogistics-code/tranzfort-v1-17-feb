// ignore_for_file: avoid_print
//
// Runtime integration: Full load lifecycle (create → search → book → trip)
// Uses REAL verified accounts used in manual testing.

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
  const password = 'Tabish%%Khan721';

  late SupabaseClient supplierClient;
  late SupabaseClient truckerClient;
  late DatabaseService supplierDb;
  late DatabaseService truckerDb;
  late User supplierUser;
  late User truckerUser;
  String? createdLoadId;

  setUpAll(() async {
    supplierClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    truckerClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
    supplierDb = DatabaseService(supplierClient);
    truckerDb = DatabaseService(truckerClient);

    final sAuth = await supplierClient.auth.signInWithPassword(
      email: supplierEmail, password: password,
    );
    expect(sAuth.user, isNotNull, reason: 'Supplier sign-in failed');
    supplierUser = sAuth.user!;
    print('Supplier UID: ${supplierUser.id}');

    final tAuth = await truckerClient.auth.signInWithPassword(
      email: truckerEmail, password: password,
    );
    expect(tAuth.user, isNotNull, reason: 'Trucker sign-in failed');
    truckerUser = tAuth.user!;
    print('Trucker UID: ${truckerUser.id}');
  });

  tearDownAll(() async {
    // Clean up: cancel the test load so it doesn't pollute real data
    if (createdLoadId != null) {
      try {
        await supplierDb.updateLoad(createdLoadId!, {'status': 'cancelled'});
        print('Cleaned up test load: $createdLoadId');
      } catch (e) {
        print('Cleanup warning: $e');
      }
    }
    await supplierClient.auth.signOut();
    await truckerClient.auth.signOut();
  });

  test('Supplier creates load → appears in getMyLoads', () async {
    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final loadData = {
      'supplier_id': supplierUser.id,
      'origin_city': 'Mumbai',
      'origin_state': 'Maharashtra',
      'dest_city': 'Pune',
      'dest_state': 'Maharashtra',
      'material': 'Steel',
      'weight_tonnes': 25.0,
      'price': 3500.0,
      'price_type': 'negotiable',
      'pickup_date': DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T').first,
      'status': 'active',
      'required_truck_type': 'open',
      'notes': 'Runtime test $marker',
    };

    final created = await supplierDb.createLoad(loadData);
    createdLoadId = created['id'] as String;
    print('Created load: $createdLoadId');
    expect(createdLoadId, isNotNull);

    final myLoads = await supplierDb.getMyLoads(supplierUser.id);
    final found = myLoads.any((l) => l['id'] == createdLoadId);
    expect(found, isTrue, reason: 'Created load must appear in getMyLoads');
  });

  test('Trucker searches active loads → finds supplier load', () async {
    expect(createdLoadId, isNotNull, reason: 'Previous test must create a load');

    final loads = await truckerDb.getActiveLoads(
      originCity: 'Mumbai',
      destCity: 'Pune',
    );
    expect(loads, isA<List<Map<String, dynamic>>>());
    final found = loads.any((l) => l['id'] == createdLoadId);
    expect(found, isTrue, reason: 'Trucker should find the supplier load');
  });

  test('Load filters — origin prefix match', () async {
    final loads = await truckerDb.getActiveLoads(originCity: 'Mum');
    for (final load in loads) {
      final origin = (load['origin_city'] as String).toLowerCase();
      expect(origin.startsWith('mum'), isTrue,
          reason: 'Origin filter should prefix-match');
    }
  });

  test('Load update persists', () async {
    expect(createdLoadId, isNotNull);
    await supplierDb.updateLoad(createdLoadId!, {
      'notes': 'Updated by runtime test',
    });
    final updated = await supplierDb.getLoadById(createdLoadId!);
    expect(updated, isNotNull);
    expect(updated!['notes'], 'Updated by runtime test');
  });

  test('getLoadById returns correct load', () async {
    expect(createdLoadId, isNotNull);
    final load = await supplierDb.getLoadById(createdLoadId!);
    expect(load, isNotNull);
    expect(load!['id'], createdLoadId);
    expect(load['origin_city'], 'Mumbai');
    expect(load['dest_city'], 'Pune');
  });

  test('Deal acceptance: status → booked, trucker assigned', () async {
    expect(createdLoadId, isNotNull);
    await supplierDb.acceptDeal(
      loadId: createdLoadId!,
      truckerId: truckerUser.id,
    );
    final load = await supplierDb.getLoadById(createdLoadId!);
    expect(load, isNotNull);
    expect(load!['status'], 'booked');
    expect(load['assigned_trucker_id'], truckerUser.id);
  });

  test('Trucker sees booked load in getMyTrips', () async {
    expect(createdLoadId, isNotNull);
    final trips = await truckerDb.getMyTrips(truckerUser.id);
    final found = trips.any((t) => t['id'] == createdLoadId);
    expect(found, isTrue, reason: 'Booked load must appear in trucker getMyTrips');
  });

  test('Trip stage update persists', () async {
    expect(createdLoadId, isNotNull);
    await supplierDb.updateTripStage(createdLoadId!, 'in_transit');
    final load = await supplierDb.getLoadById(createdLoadId!);
    expect(load, isNotNull);
    expect(load!['trip_stage'], 'in_transit');
    expect(load['status'], 'in_transit');
  });
}
