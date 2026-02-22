// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/src/core/services/database_service.dart';

void main() {
  const supabaseUrl = 'https://fjixgerqwftvkhrkfjbt.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqaXhnZXJxd2Z0dmtocmtmamJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDA2NTgsImV4cCI6MjA4NTUxNjY1OH0.ogamClsIOa2exygt8j61bPKcHTPsj3vQXRitw_KcmNs';
  const truckerEmail = 'info.tabish.khan@gmail.com';
  const truckerPassword = 'Tabish%%Khan721';

  late SupabaseClient client;
  late DatabaseService db;
  late User user;
  String? createdTruckId;

  setUpAll(() async {
    client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    db = DatabaseService(client);

    final auth = await client.auth.signInWithPassword(
      email: truckerEmail, password: truckerPassword,
    );
    expect(auth.user, isNotNull);
    user = auth.user!;
  });

  tearDownAll(() async {
    // Clean up test truck
    if (createdTruckId != null) {
      try {
        await db.deleteTruck(createdTruckId!);
      } catch (_) {}
    }
    await client.auth.signOut();
  });

  test('addTruck → appears in getMyTrucks', () async {
    final marker = DateTime.now().millisecondsSinceEpoch.toString();
    final truckData = {
      'owner_id': user.id,
      'truck_number': 'MH12RT${marker.substring(marker.length - 4)}',
      'body_type': 'open',
      'capacity_tonnes': 25.0,
      'tyres': 10,
      'status': 'pending',
    };

    final created = await db.addTruck(truckData);
    createdTruckId = created['id'] as String;
    expect(createdTruckId, isNotNull);

    final myTrucks = await db.getMyTrucks(user.id);
    final found = myTrucks.any((t) => t['id'] == createdTruckId);
    expect(found, isTrue, reason: 'Created truck should appear in getMyTrucks');
  });

  test('getTruckById returns correct truck', () async {
    expect(createdTruckId, isNotNull);

    final truck = await db.getTruckById(createdTruckId!);
    expect(truck, isNotNull);
    expect(truck!['id'], createdTruckId);
    expect(truck['owner_id'], user.id);
    expect(truck['body_type'], 'open');
  });

  test('deleteTruck removes it', () async {
    expect(createdTruckId, isNotNull);

    await db.deleteTruck(createdTruckId!);

    final truck = await db.getTruckById(createdTruckId!);
    expect(truck, isNull, reason: 'Deleted truck should not be retrievable');

    // Mark as cleaned up so tearDownAll doesn't try again
    createdTruckId = null;
  });
}
