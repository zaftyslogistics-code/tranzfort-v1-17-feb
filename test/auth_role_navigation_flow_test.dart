// ignore_for_file: avoid_print
//
// Higher-level automated test that validates the full auth → role → navigation
// contract at both the source-contract level AND runtime level.
//
// Source-contract tests verify that routing invariants are preserved in code.
// Runtime tests verify that role-gated DB operations and cross-role visibility
// work end-to-end against the live Supabase backend.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tranzfort/src/core/services/database_service.dart';

void main() {
  // ─── PART 1: Source-contract assertions ───────────────────────────────────

  group('Auth → Role → Navigation source contracts', () {
    late String routerSource;
    late String signupSource;
    late String splashSource;
    late String roleSelectionSource;
    late String loginSource;
    late String dbSource;

    setUpAll(() {
      routerSource = File('lib/src/core/routing/app_router.dart').readAsStringSync();
      signupSource = File('lib/src/features/auth/presentation/screens/signup_screen.dart').readAsStringSync();
      splashSource = File('lib/src/features/auth/presentation/screens/splash_screen.dart').readAsStringSync();
      roleSelectionSource = File('lib/src/features/auth/presentation/screens/role_selection_screen.dart').readAsStringSync();
      loginSource = File('lib/src/features/auth/presentation/screens/login_screen.dart').readAsStringSync();
      dbSource = File('lib/src/core/services/database_service.dart').readAsStringSync();
    });

    test('Router exempts all auth pages from redirect', () {
      for (final path in ['/login', '/signup', '/otp-verification', '/forgot-password']) {
        expect(routerSource, contains("'$path'"),
            reason: '$path must be in authPaths exemption list');
      }
      expect(routerSource, contains("if (authPaths.contains(currentPath)) return null;"));
    });

    test('Unauthenticated users are redirected to /login', () {
      expect(routerSource, contains("if (!isAuthenticated) return '/login';"));
    });

    test('Users without a role are redirected to /role-selection', () {
      // hasResolvedRole guard prevents premature redirect during async role loading
      expect(routerSource, contains("role == null && currentPath != '/role-selection'"));
      expect(routerSource, contains("return '/role-selection';"));
    });

    test('Supplier-only paths are guarded against trucker access', () {
      for (final path in ['/supplier-dashboard', '/post-load', '/my-loads', '/supplier-verification', '/supplier-profile']) {
        expect(routerSource, contains("'$path'"),
            reason: '$path must be in supplierOnlyPaths');
      }
      expect(routerSource, contains("if (role == 'trucker' && supplierOnlyPaths.contains(currentPath))"));
    });

    test('Trucker-only paths are guarded against supplier access', () {
      for (final path in ['/find-loads', '/my-fleet', '/add-truck', '/my-trips', '/trucker-verification', '/trucker-profile']) {
        expect(routerSource, contains("'$path'"),
            reason: '$path must be in truckerOnlyPaths');
      }
      expect(routerSource, contains("if (role == 'supplier' && truckerOnlyPaths.contains(currentPath))"));
    });

    test('Post-load route has verification gate', () {
      expect(routerSource, contains("if (currentPath == '/post-load')"));
      expect(routerSource, contains("verificationStatus != 'verified'"));
      expect(routerSource, contains("return '/supplier-verification';"));
    });

    test('Signup signs out after account creation to prevent auto-login', () {
      expect(signupSource, contains('await authService.signOut();'));
      expect(signupSource, contains('invalidateAllUserProviders(ref);'));
    });

    test('Splash screen checks auth and routes by role', () {
      expect(splashSource, contains('currentUser'));
      expect(splashSource, contains('/login'));
      expect(splashSource, contains('/role-selection'));
    });

    test('Login screen invalidates providers and navigates by role', () {
      expect(loginSource, contains('invalidateAllUserProviders'));
      expect(loginSource, contains('/supplier-dashboard'));
      expect(loginSource, contains('/find-loads'));
    });

    test('Role selection creates role-specific data idempotently', () {
      expect(roleSelectionSource, contains("await db.createSupplierData(userId, {});"));
      expect(roleSelectionSource, contains("await db.createTruckerData(userId, {});"));
      // invalidateAllUserProviders(ref) invalidates all user providers including userRoleProvider
      expect(roleSelectionSource, contains("invalidateAllUserProviders(ref);"));
    });

    test('Database service uses upsert for role-row creation', () {
      // Both createSupplierData and createTruckerData should use upsert
      expect(dbSource, contains('onConflict'));
    });
  });

  // ─── PART 2: Runtime integration – role-gated operations ──────────────────

  group('Auth → Role → Navigation runtime integration', () {
    const supabaseUrl = 'https://fjixgerqwftvkhrkfjbt.supabase.co';
    const supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqaXhnZXJxd2Z0dmtocmtmamJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDA2NTgsImV4cCI6MjA4NTUxNjY1OH0.ogamClsIOa2exygt8j61bPKcHTPsj3vQXRitw_KcmNs';

    const supplierEmail = 'test-supplier@example.com';
    const supplierPassword = 'Tabish%%Khan721';
    const truckerEmail = 'test-trucker@example.com';
    const truckerPassword = 'Tabish%%Khan721';

    late SupabaseClient supplierClient;
    late SupabaseClient truckerClient;
    late DatabaseService supplierDb;
    late DatabaseService truckerDb;
    late User supplierUser;
    late User truckerUser;

    setUpAll(() async {
      supplierClient = SupabaseClient(supabaseUrl, supabaseAnonKey);
      truckerClient = SupabaseClient(supabaseUrl, supabaseAnonKey);

      supplierDb = DatabaseService(supplierClient);
      truckerDb = DatabaseService(truckerClient);

      final sAuth = await supplierClient.auth.signInWithPassword(
        email: supplierEmail,
        password: supplierPassword,
      );
      expect(sAuth.user, isNotNull, reason: 'Supplier sign-in required.');
      supplierUser = sAuth.user!;

      final tAuth = await truckerClient.auth.signInWithPassword(
        email: truckerEmail,
        password: truckerPassword,
      );
      expect(tAuth.user, isNotNull, reason: 'Trucker sign-in required.');
      truckerUser = tAuth.user!;
    });

    tearDownAll(() async {
      await supplierClient.auth.signOut();
      await truckerClient.auth.signOut();
    });

    test('Supplier profile has correct role and can read own supplier data', () async {
      final profile = await supplierDb.getUserProfile(supplierUser.id);
      expect(profile, isNotNull);
      expect(profile!['current_role'], 'supplier',
          reason: 'Supplier profile must have current_role=supplier');

      final supplierData = await supplierDb.getSupplierData(supplierUser.id);
      expect(supplierData, isNotNull,
          reason: 'Supplier must have a suppliers row after role selection');
    });

    test('Trucker profile has correct role and can read own trucker data', () async {
      final profile = await truckerDb.getUserProfile(truckerUser.id);
      expect(profile, isNotNull);
      expect(profile!['current_role'], 'trucker',
          reason: 'Trucker profile must have current_role=trucker');

      final truckerData = await truckerDb.getTruckerData(truckerUser.id);
      expect(truckerData, isNotNull,
          reason: 'Trucker must have a truckers row after role selection');
    });

    test('Supplier cannot read trucker-specific data for another user', () async {
      // Supplier trying to read trucker data for the trucker user
      // Should return null due to RLS (only own row readable)
      final crossRead = await supplierDb.getTruckerData(truckerUser.id);
      expect(crossRead, isNull,
          reason: 'RLS should prevent supplier from reading trucker data of another user');
    });

    test('Trucker cannot read supplier-specific data for another user', () async {
      final crossRead = await truckerDb.getSupplierData(supplierUser.id);
      expect(crossRead, isNull,
          reason: 'RLS should prevent trucker from reading supplier data of another user');
    });

    test('Both roles can read public profiles of each other', () async {
      final supplierPublic = await truckerDb.getPublicProfile(supplierUser.id);
      final truckerPublic = await supplierDb.getPublicProfile(truckerUser.id);

      expect(supplierPublic, isNotNull,
          reason: 'Trucker should be able to read supplier public profile');
      expect(truckerPublic, isNotNull,
          reason: 'Supplier should be able to read trucker public profile');
    });

    test('Trucker can search active loads (core navigation target)', () async {
      final loads = await truckerDb.getActiveLoads(
        originCity: '',
        destCity: '',
        truckType: 'Any',
        sortOrder: 'none',
        verifiedOnly: false,
      );
      expect(loads, isA<List<Map<String, dynamic>>>(),
          reason: 'Trucker must be able to query active loads');
    });

    test('Supplier verification status update persists correctly', () async {
      // Read current status
      final before = await supplierDb.getUserProfile(supplierUser.id);
      final currentStatus = before?['verification_status'] as String?;

      // Set to pending (simulating verification submission)
      await supplierDb.updateProfile(supplierUser.id, {
        'verification_status': 'pending',
      });

      final after = await supplierDb.getUserProfile(supplierUser.id);
      expect(after?['verification_status'], 'pending',
          reason: 'Verification status update must persist');

      // Restore original status if it was different
      if (currentStatus != null && currentStatus != 'pending') {
        await supplierDb.updateProfile(supplierUser.id, {
          'verification_status': currentStatus,
        });
      }
    });

    test('Idempotent role-row creation does not throw on duplicate', () async {
      // Calling createSupplierData twice should not throw
      await supplierDb.createSupplierData(supplierUser.id, {});
      await supplierDb.createSupplierData(supplierUser.id, {});

      // Calling createTruckerData twice should not throw
      await truckerDb.createTruckerData(truckerUser.id, {});
      await truckerDb.createTruckerData(truckerUser.id, {});
    });
  });
}
