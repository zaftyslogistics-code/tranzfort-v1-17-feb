import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class AppDialogs {
  AppDialogs._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String description,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AppTypography.h3Subsection),
        content: Text(
          description,
          style: AppTypography.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              cancelText,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDestructive ? AppColors.error : AppColors.brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : isSuccess
                ? AppColors.success
                : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration,
      ),
    );
  }

  /// Maps common exception types to friendly user-facing messages.
  static String errorToUserMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet. Check your connection.';
    }
    if (error is TimeoutException) {
      return 'Request timed out. Try again.';
    }
    final msg = error.toString();
    if (msg.contains('AuthException') || msg.contains('auth/')) {
      return 'Login failed. Check your details.';
    }
    if (msg.contains('PostgrestException') ||
        msg.contains('PGRST') ||
        msg.contains('supabase')) {
      return 'Something went wrong. Try again.';
    }
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'No internet. Check your connection.';
    }
    // Strip technical prefixes for anything else
    return msg
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .trim();
  }

  static void showErrorSnackBar(BuildContext context, dynamic error) {
    showSnackBar(context, errorToUserMessage(error), isError: true);
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, isSuccess: true);
  }
}
