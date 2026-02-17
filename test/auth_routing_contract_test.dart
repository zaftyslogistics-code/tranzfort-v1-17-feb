import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth + routing regression contracts', () {
    test('Signup explicitly signs out after account creation', () {
      final source = File(
        'lib/src/features/auth/presentation/screens/signup_screen.dart',
      ).readAsStringSync();

      expect(source, contains('await authService.signOut();'));
      expect(source, contains('invalidateAllUserProviders(ref);'));
      expect(
        source,
        contains('Please confirm your email, then log in.'),
      );
    });

    test('Role selection uses idempotent role-row writes through DB service calls', () {
      final source = File(
        'lib/src/features/auth/presentation/screens/role_selection_screen.dart',
      ).readAsStringSync();

      expect(source, contains("await db.createSupplierData(userId, {});"));
      expect(source, contains("await db.createTruckerData(userId, {});"));
    });

    test('Router keeps auth pages exempt and gates protected pages by auth + role', () {
      final source = File(
        'lib/src/core/routing/app_router.dart',
      ).readAsStringSync();

      expect(source, contains("'/login'"));
      expect(source, contains("if (!isAuthenticated) return '/login';"));
      expect(source, contains('final hasResolvedRole = roleAsync.hasValue;'));
      expect(source, contains("if (hasResolvedRole && role == null && currentPath != '/role-selection')"));
      expect(source, contains("return '/role-selection';"));
    });
  });
}
