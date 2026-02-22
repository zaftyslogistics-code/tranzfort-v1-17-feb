import 'dart:developer' as dev;

/// UX-1: Push notification service placeholder.
/// When FCM is integrated, this service will handle:
/// - Token registration with Supabase user profile
/// - Foreground/background message handling
/// - Notification channel setup (Android)
/// - Badge count management
/// - Deep link routing from notification taps
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _initialized = false;

  /// Initialize push notification service.
  /// Call this from main.dart after Supabase init.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    dev.log('[PushNotificationService] Placeholder initialized — FCM not yet configured');
    // TODO: Add firebase_messaging dependency
    // TODO: Request notification permissions
    // TODO: Get FCM token and store in user profile
    // TODO: Set up foreground message handler
    // TODO: Set up background message handler
    // TODO: Configure notification channels for Android
  }

  /// Register device token with backend.
  Future<void> registerToken(String userId) async {
    dev.log('[PushNotificationService] registerToken($userId) — placeholder');
    // TODO: Get FCM token via FirebaseMessaging.instance.getToken()
    // TODO: Store token in Supabase profiles.fcm_token column
  }

  /// Unregister device token (on logout).
  Future<void> unregisterToken(String userId) async {
    dev.log('[PushNotificationService] unregisterToken($userId) — placeholder');
    // TODO: Clear fcm_token from Supabase profile
  }

  /// Handle notification tap — route to appropriate screen.
  void handleNotificationTap(Map<String, dynamic> data) {
    dev.log('[PushNotificationService] handleNotificationTap: $data');
    // TODO: Parse notification data and navigate via GoRouter
    // Expected data keys: type (chat, load, trip), id
  }

  /// Show local notification (for foreground messages).
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    dev.log('[PushNotificationService] showLocal: $title — $body');
    // TODO: Use flutter_local_notifications to display
  }
}
