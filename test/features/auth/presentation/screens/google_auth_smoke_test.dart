import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tranzfort/src/features/auth/presentation/screens/login_screen.dart';
import 'package:tranzfort/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:tranzfort/l10n/app_localizations.dart';

void main() {
  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('Google Sign-In/Sign-Up Smoke Tests', () {
    testWidgets('Login Screen shows Continue with Google button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const LoginScreen()));
      
      // We need to settle animations
      await tester.pumpAndSettle();

      // Find the Google button text
      final googleButtonFinder = find.text('Continue with Google');
      
      // Verify it exists
      expect(googleButtonFinder, findsOneWidget);
    });

    testWidgets('Signup Screen shows Continue with Google button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SignupScreen()));
      
      // We need to settle animations
      await tester.pumpAndSettle();

      // Find the Google button text
      final googleButtonFinder = find.text('Continue with Google');
      
      // Verify it exists
      expect(googleButtonFinder, findsOneWidget);
    });
  });
}
