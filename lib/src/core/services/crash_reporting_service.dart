import 'package:flutter/foundation.dart';

/// Task 9.8: Crash Reporting scaffold.
/// Ready for Sentry integration — DSN provided via --dart-define=SENTRY_DSN=...
/// No PII is captured (no phone/email). Only user_id and role.
///
/// To enable:
/// 1. Add `sentry_flutter: ^8.x.x` to pubspec.yaml
/// 2. Uncomment SentryFlutter.init() in main.dart
/// 3. Pass DSN via: flutter run --dart-define=SENTRY_DSN=https://...
class CrashReportingService {
  static const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static bool get isEnabled => _sentryDsn.isNotEmpty;

  /// Initialize crash reporting. Call in main() before runApp().
  /// Currently a no-op scaffold — uncomment Sentry code when ready.
  static Future<void> init() async {
    if (!isEnabled) {
      debugPrint('CrashReporting: disabled (no SENTRY_DSN)');
      return;
    }

    debugPrint('CrashReporting: initializing with DSN');

    // TODO: Uncomment when sentry_flutter is added to pubspec.yaml
    // await SentryFlutter.init(
    //   (options) {
    //     options.dsn = _sentryDsn;
    //     options.tracesSampleRate = 0.2;
    //     options.environment = kReleaseMode ? 'production' : 'development';
    //     options.beforeSend = _beforeSend;
    //   },
    //   appRunner: () => runApp(const ProviderScope(child: TranZfortApp())),
    // );
  }

  /// Set user context after login (no PII — only ID and role).
  static void setUserContext({
    required String userId,
    required String role,
    String? locale,
  }) {
    debugPrint('CrashReporting: setUser $userId ($role)');

    // TODO: Uncomment when sentry_flutter is added
    // Sentry.configureScope((scope) {
    //   scope.setUser(SentryUser(
    //     id: userId,
    //     data: {'role': role, if (locale != null) 'locale': locale},
    //   ));
    // });
  }

  /// Clear user context on logout.
  static void clearUserContext() {
    debugPrint('CrashReporting: clearUser');

    // TODO: Uncomment when sentry_flutter is added
    // Sentry.configureScope((scope) => scope.setUser(null));
  }

  /// Capture a non-fatal exception manually.
  static void captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? hint,
  }) {
    debugPrint('CrashReporting: captureException $exception');

    // TODO: Uncomment when sentry_flutter is added
    // Sentry.captureException(exception, stackTrace: stackTrace, hint: hint);
  }

  /// Add a breadcrumb for debugging context.
  static void addBreadcrumb(String message, {String? category}) {
    // TODO: Uncomment when sentry_flutter is added
    // Sentry.addBreadcrumb(Breadcrumb(
    //   message: message,
    //   category: category,
    //   timestamp: DateTime.now(),
    // ));
  }

  // /// Strip PII from events before sending.
  // static SentryEvent? _beforeSend(SentryEvent event, Hint hint) {
  //   // Ensure no PII leaks through
  //   return event;
  // }
}
