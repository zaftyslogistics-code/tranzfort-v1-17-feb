import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String routerSource;

  setUpAll(() {
    routerSource = File('lib/src/core/routing/app_router.dart').readAsStringSync();
  });

  group('Router auth path exemptions', () {
    test('all auth paths are exempt from redirect', () {
      for (final path in ['/login', '/signup', '/otp-verification', '/forgot-password', '/onboarding']) {
        expect(routerSource, contains("'$path'"),
            reason: '$path must be in authPaths exemption list');
      }
      expect(routerSource, contains('if (authPaths.contains(currentPath)) return null;'));
    });

    test('splash always allowed', () {
      expect(routerSource, contains("if (currentPath == '/splash') return null;"));
    });
  });

  group('Router authentication guard', () {
    test('unauthenticated users redirected to /login', () {
      expect(routerSource, contains("if (!isAuthenticated) return '/login';"));
    });
  });

  group('Router role guard', () {
    test('no role → /role-selection redirect', () {
      expect(routerSource, contains("role == null && currentPath != '/role-selection'"));
      expect(routerSource, contains("return '/role-selection';"));
    });

    test('supplier-only paths guarded against trucker', () {
      for (final path in ['/supplier-dashboard', '/post-load', '/my-loads', '/supplier-verification', '/supplier-profile']) {
        expect(routerSource, contains("'$path'"),
            reason: '$path must be in supplierOnlyPaths');
      }
      expect(routerSource, contains("if (role == 'supplier' && truckerOnlyPaths.contains(currentPath))"));
    });

    test('trucker-only paths guarded against supplier', () {
      for (final path in ['/find-loads', '/my-fleet', '/add-truck', '/my-trips', '/trucker-verification', '/trucker-profile']) {
        expect(routerSource, contains("'$path'"),
            reason: '$path must be in truckerOnlyPaths');
      }
      expect(routerSource, contains("if (role == 'trucker' && supplierOnlyPaths.contains(currentPath))"));
    });
  });

  group('Router verification gate', () {
    test('post-load requires verification', () {
      expect(routerSource, contains("if (currentPath == '/post-load')"));
      expect(routerSource, contains("verificationStatus != 'verified'"));
      expect(routerSource, contains("return '/supplier-verification';"));
    });
  });

  group('Router route registration', () {
    test('all expected routes have GoRoute entries', () {
      final expectedPaths = [
        '/splash', '/login', '/signup', '/otp-verification', '/forgot-password',
        '/role-selection', '/supplier-dashboard', '/post-load', '/my-loads',
        '/trucker-dashboard', '/find-loads', '/my-fleet', '/add-truck', '/my-trips',
        '/messages', '/bot-chat', '/settings', '/help-support', '/my-tickets',
        '/navigation', '/navigation/preview', '/navigation/active',
        '/navigation/saved-places',
      ];
      for (final path in expectedPaths) {
        expect(routerSource, contains("path: '$path'"),
            reason: 'GoRoute for $path must exist');
      }
    });

    test('parameterized routes registered', () {
      expect(routerSource, contains("path: '/chat/:conversationId'"));
      expect(routerSource, contains("path: '/load-detail/:loadId'"));
      expect(routerSource, contains("path: '/ticket/:ticketId'"));
      expect(routerSource, contains("path: '/edit-load/:loadId'"));
      expect(routerSource, contains("path: '/super-load-request/:loadId'"));
      expect(routerSource, contains("path: '/navigation/live-tracking/:loadId'"));
    });
  });

  group('Router singleton architecture', () {
    test('uses _RouterNotifier with ref.listen (not ref.watch)', () {
      expect(routerSource, contains('class _RouterNotifier'));
      expect(routerSource, contains('_ref.listen(currentUserProvider'));
      expect(routerSource, contains('_ref.listen(userRoleProvider'));
    });

    test('redirect uses ref.read (not ref.watch)', () {
      expect(routerSource, contains('ref.read(currentUserProvider)'));
      expect(routerSource, contains('ref.read(userRoleProvider)'));
    });
  });
}
