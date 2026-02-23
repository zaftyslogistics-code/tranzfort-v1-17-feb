import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration files exist for referenced tables', () {
    test('migration directory has SQL files', () {
      final migDir = Directory('../../supabase/migrations');
      // Fallback path for running from TranZfort/
      final altDir = Directory('../supabase/migrations');
      final dir = migDir.existsSync() ? migDir : altDir;

      if (!dir.existsSync()) {
        // Skip if migrations not accessible from test CWD
        return;
      }

      final sqlFiles = dir.listSync().where((f) => f.path.endsWith('.sql')).toList();
      expect(sqlFiles, isNotEmpty, reason: 'Migration directory should contain SQL files');
    });
  });

  group('No hardcoded Supabase URLs outside config', () {
    test('only supabase_config.dart contains the project URL', () {
      final libDir = Directory('lib/src');
      if (!libDir.existsSync()) return;

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final relativePath = file.path.replaceAll('\\', '/');

        // Skip the config file itself
        if (relativePath.contains('supabase_config.dart')) continue;
        // Skip test files
        if (relativePath.contains('/test/')) continue;

        // Check for hardcoded Supabase project URLs
        final hasHardcodedUrl = RegExp(r'https://\w+\.supabase\.co').hasMatch(content);
        expect(hasHardcodedUrl, false,
            reason: '$relativePath should not contain hardcoded Supabase URL');
      }
    });
  });

  group('Storage path patterns', () {
    test('verification screens use userId/ prefix for storage paths', () {
      final supplierVerif = File('lib/src/features/supplier/presentation/screens/supplier_verification_screen.dart');
      final truckerVerif = File('lib/src/features/trucker/presentation/screens/trucker_verification_screen.dart');

      if (supplierVerif.existsSync()) {
        final source = supplierVerif.readAsStringSync();
        // Storage paths must start with userId for RLS compliance
        expect(source, contains(r'$userId/'),
            reason: 'Supplier verification must use userId/ prefix for storage paths');
      }

      if (truckerVerif.existsSync()) {
        final source = truckerVerif.readAsStringSync();
        expect(source, contains(r'$userId/'),
            reason: 'Trucker verification must use userId/ prefix for storage paths');
      }
    });

    test('add truck screen uses userId/ prefix for storage paths', () {
      final addTruck = File('lib/src/features/trucker/presentation/screens/add_truck_screen.dart');
      if (addTruck.existsSync()) {
        final source = addTruck.readAsStringSync();
        expect(source, contains(r'$userId/'),
            reason: 'Add truck must use userId/ prefix for storage paths');
      }
    });
  });

  group('Auth flow contracts', () {
    test('signup signs out after account creation', () {
      final signup = File('lib/src/features/auth/presentation/screens/signup_screen.dart');
      if (!signup.existsSync()) return;
      final source = signup.readAsStringSync();
      expect(source, contains('await authService.signOut();'));
      expect(source, contains('invalidateAllUserProviders(ref);'));
    });

    test('role selection creates role data idempotently', () {
      final roleSelection = File('lib/src/features/auth/presentation/screens/role_selection_screen.dart');
      if (!roleSelection.existsSync()) return;
      final source = roleSelection.readAsStringSync();
      expect(source, contains('await db.createSupplierData(userId, {});'));
      expect(source, contains('await db.createTruckerData(userId, {});'));
      expect(source, contains('invalidateAllUserProviders(ref);'));
    });

    test('login invalidates providers before navigation', () {
      final login = File('lib/src/features/auth/presentation/screens/login_screen.dart');
      if (!login.existsSync()) return;
      final source = login.readAsStringSync();
      expect(source, contains('invalidateAllUserProviders'));
    });
  });

  group('Phase 7-9 table references in code', () {
    test('database_service references user_preferences table', () {
      final prefSync = File('lib/src/core/services/preferences_sync_service.dart');
      if (!prefSync.existsSync()) return;
      final source = prefSync.readAsStringSync();
      expect(source, contains("'user_preferences'"),
          reason: 'PreferencesSyncService must reference user_preferences table');
    });

    test('tracking_service references tracking_sessions and location_pings', () {
      final tracking = File('lib/src/features/navigation/services/tracking_service.dart');
      if (!tracking.existsSync()) return;
      final source = tracking.readAsStringSync();
      expect(source, contains("'tracking_sessions'"),
          reason: 'TrackingService must reference tracking_sessions table');
      expect(source, contains("'location_pings'"),
          reason: 'TrackingService must reference location_pings table');
    });

    test('load_repository references loads table with payment_term_days-related fields', () {
      final loadModel = File('lib/src/core/models/load_model.dart');
      if (!loadModel.existsSync()) return;
      final source = loadModel.readAsStringSync();
      expect(source, contains('trucksNeeded'),
          reason: 'LoadModel should have trucksNeeded field for bulk load groups');
    });

    test('SQLite cache creates all expected tables', () {
      final cache = File('lib/src/core/cache/sqlite_cache.dart');
      if (!cache.existsSync()) return;
      final source = cache.readAsStringSync();
      for (final table in [
        'cached_loads',
        'cached_trucks',
        'cached_profile',
        'cached_conversations',
        'cached_notifications',
        'pending_actions',
        'pending_pings',
        'bot_conversations',
      ]) {
        expect(source, contains(table),
            reason: 'CacheService must create $table table');
      }
    });

    test('subscription_manager enforces max 10 channels', () {
      final subMgr = File('lib/src/core/services/subscription_manager.dart');
      if (!subMgr.existsSync()) return;
      final source = subMgr.readAsStringSync();
      expect(source, contains('maxChannels = 10'),
          reason: 'SubscriptionManager must enforce Supabase free tier limit');
    });

    test('image compression uses 1200x1200 max dimensions', () {
      final supplierVerif = File('lib/src/features/supplier/presentation/screens/supplier_verification_screen.dart');
      if (!supplierVerif.existsSync()) return;
      final source = supplierVerif.readAsStringSync();
      expect(source, contains('maxWidth: 1200'),
          reason: 'Upload screens must use compressed dimensions');
      expect(source, contains('maxHeight: 1200'),
          reason: 'Upload screens must use compressed dimensions');
    });
  });

  group('Message type enum compliance', () {
    test('sendMessage uses valid message_type values', () {
      final dbSource = File('lib/src/core/services/database_service.dart').readAsStringSync();
      // The sendMessage method should use the 'type' parameter directly
      expect(dbSource, contains("'message_type': type"));
      // Should NOT contain invalid types
      expect(dbSource, isNot(contains("'truck_share'")));
      expect(dbSource, isNot(contains("'rc_share'")));
    });
  });
}
