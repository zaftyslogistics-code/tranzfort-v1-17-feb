import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  static void lightImpact() => HapticFeedback.lightImpact();
  static void mediumImpact() => HapticFeedback.mediumImpact();
  static void heavyImpact() => HapticFeedback.heavyImpact();
  static void selectionClick() => HapticFeedback.selectionClick();
  static void vibrate() => HapticFeedback.vibrate();

  /// Use for primary actions: Post, Accept, Book, Search, Login, Signup
  static void onPrimaryAction() => HapticFeedback.mediumImpact();

  /// Use for send message, add truck
  static void onSend() => HapticFeedback.lightImpact();

  /// Use for destructive actions: delete, deactivate, logout
  static void onDestructive() => HapticFeedback.heavyImpact();

  /// Use for tab/nav selection
  static void onSelect() => HapticFeedback.selectionClick();
}
