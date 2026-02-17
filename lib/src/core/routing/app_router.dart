import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_service_provider.dart';
import '../utils/animations.dart';

// Screen imports
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/supplier/presentation/screens/supplier_dashboard_screen.dart';
import '../../features/supplier/presentation/screens/post_load_screen.dart';
import '../../features/supplier/presentation/screens/my_loads_screen.dart';
import '../../features/supplier/presentation/screens/load_detail_screen.dart';
import '../../features/supplier/presentation/screens/super_load_request_screen.dart';
import '../../features/supplier/presentation/screens/super_dashboard_screen.dart';
import '../../features/supplier/presentation/screens/supplier_verification_screen.dart';
import '../../features/supplier/presentation/screens/supplier_profile_screen.dart';
import '../../features/supplier/presentation/screens/payout_profile_screen.dart';
import '../../features/trucker/presentation/screens/find_loads_screen.dart';
import '../../features/trucker/presentation/screens/my_fleet_screen.dart';
import '../../features/trucker/presentation/screens/add_truck_screen.dart';
import '../../features/trucker/presentation/screens/my_trips_screen.dart';
import '../../features/trucker/presentation/screens/trucker_verification_screen.dart';
import '../../features/trucker/presentation/screens/trucker_profile_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/shared/presentation/screens/settings_screen.dart';
import '../../features/shared/presentation/screens/help_support_screen.dart';
import '../../features/shared/presentation/screens/my_tickets_screen.dart';
import '../../features/shared/presentation/screens/ticket_detail_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(currentUserProvider, (prev, next) => notifyListeners());
    _ref.listen(userRoleProvider, (prev, next) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(currentUserProvider);
      final isAuthenticated = authState.whenOrNull(
            data: (s) => s.session != null,
          ) ??
          false;

      final currentPath = state.matchedLocation;

      // Auth screens that don't require redirect
      const authPaths = [
        '/login',
        '/signup',
        '/otp-verification',
        '/forgot-password',
      ];

      // Don't redirect away from auth screens when authenticated
      // Login/OTP screens handle post-auth navigation explicitly
      if (authPaths.contains(currentPath)) return null;

      // Splash always allowed
      if (currentPath == '/splash') return null;

      // Not authenticated → login
      if (!isAuthenticated) return '/login';

      // Authenticated — check role
      final roleAsync = ref.read(userRoleProvider);
      final role = roleAsync.whenOrNull(data: (r) => r);
      final hasResolvedRole = roleAsync.hasValue;

      // No role → role selection
      if (hasResolvedRole && role == null && currentPath != '/role-selection') {
        return '/role-selection';
      }

      // Role-based route guards
      const supplierOnlyPaths = [
        '/supplier-dashboard',
        '/post-load',
        '/my-loads',
        '/supplier/super-dashboard',
        '/supplier-verification',
        '/supplier-profile',
        '/payout-profile',
      ];

      const truckerOnlyPaths = [
        '/find-loads',
        '/my-fleet',
        '/add-truck',
        '/my-trips',
        '/trucker-verification',
        '/trucker-profile',
      ];

      if (role == 'supplier' && truckerOnlyPaths.contains(currentPath)) {
        return '/supplier-dashboard';
      }
      if (role == 'trucker' && supplierOnlyPaths.contains(currentPath)) {
        return '/find-loads';
      }

      // Verification gate: suppliers must be verified to access post-load.
      // We only enforce when profile is already resolved to avoid false redirects.
      if (currentPath == '/post-load') {
        final profileAsync = ref.read(userProfileProvider);
        final verificationStatus =
            profileAsync.valueOrNull?['verification_status'] as String?;
        if (verificationStatus != null && verificationStatus != 'verified') {
          return '/supplier-verification';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/otp-verification',
        name: 'otp-verification',
        pageBuilder: (context, state) {
          final mobile = state.extra as String? ?? '';
          return fadeSlideTransitionPage(
            key: state.pageKey,
            child: OtpVerificationScreen(mobile: mobile),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/role-selection',
        name: 'role-selection',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const RoleSelectionScreen(),
        ),
      ),

      // ─── SUPPLIER ROUTES ───
      GoRoute(
        path: '/supplier-dashboard',
        name: 'supplier-dashboard',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const SupplierDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/post-load',
        name: 'post-load',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const PostLoadScreen(),
        ),
      ),
      GoRoute(
        path: '/my-loads',
        name: 'my-loads',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const MyLoadsScreen(),
        ),
      ),
      GoRoute(
        path: '/load-detail/:loadId',
        name: 'load-detail',
        pageBuilder: (context, state) {
          final loadId = state.pathParameters['loadId']!;
          return fadeSlideTransitionPage(
            key: state.pageKey,
            child: LoadDetailScreen(loadId: loadId),
          );
        },
      ),
      GoRoute(
        path: '/super-load-request/:loadId',
        name: 'super-load-request',
        pageBuilder: (context, state) {
          final loadId = state.pathParameters['loadId']!;
          return fadeSlideTransitionPage(
            key: state.pageKey,
            child: SuperLoadRequestScreen(loadId: loadId),
          );
        },
      ),
      GoRoute(
        path: '/supplier/super-dashboard',
        name: 'super-dashboard',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const SuperDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/supplier-verification',
        name: 'supplier-verification',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const SupplierVerificationScreen(),
        ),
      ),
      GoRoute(
        path: '/supplier-profile',
        name: 'supplier-profile',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const SupplierProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/payout-profile',
        name: 'payout-profile',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const PayoutProfileScreen(),
        ),
      ),

      // ─── TRUCKER ROUTES ───
      GoRoute(
        path: '/find-loads',
        name: 'find-loads',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const FindLoadsScreen(),
        ),
      ),
      GoRoute(
        path: '/my-fleet',
        name: 'my-fleet',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const MyFleetScreen(),
        ),
      ),
      GoRoute(
        path: '/add-truck',
        name: 'add-truck',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const AddTruckScreen(),
        ),
      ),
      GoRoute(
        path: '/my-trips',
        name: 'my-trips',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const MyTripsScreen(),
        ),
      ),
      GoRoute(
        path: '/trucker-verification',
        name: 'trucker-verification',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const TruckerVerificationScreen(),
        ),
      ),
      GoRoute(
        path: '/trucker-profile',
        name: 'trucker-profile',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const TruckerProfileScreen(),
        ),
      ),

      // ─── CHAT ROUTES ───
      GoRoute(
        path: '/messages',
        name: 'messages',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const ChatListScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        name: 'chat',
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return fadeSlideTransitionPage(
            key: state.pageKey,
            child: ChatScreen(conversationId: conversationId),
          );
        },
      ),

      // ─── SHARED ROUTES ───
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/help-support',
        name: 'help-support',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const HelpSupportScreen(),
        ),
      ),
      GoRoute(
        path: '/my-tickets',
        name: 'my-tickets',
        pageBuilder: (context, state) => fadeSlideTransitionPage(
          key: state.pageKey,
          child: const MyTicketsScreen(),
        ),
      ),
      GoRoute(
        path: '/ticket/:ticketId',
        name: 'ticket-detail',
        pageBuilder: (context, state) {
          final ticketId = state.pathParameters['ticketId']!;
          return fadeSlideTransitionPage(
            key: state.pageKey,
            child: TicketDetailScreen(ticketId: ticketId),
          );
        },
      ),
    ],
  );
});
