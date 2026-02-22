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

    // Network errors
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable')) {
      return 'No internet. Check your connection.';
    }

    // Auth errors
    if (msg.contains('AuthException') || msg.contains('auth/')) {
      if (msg.contains('invalid_credentials') || msg.contains('Invalid login')) {
        return 'Wrong email or password. Try again.';
      }
      if (msg.contains('email_not_confirmed')) {
        return 'Please verify your email first.';
      }
      return 'Login failed. Check your details.';
    }

    // Rate limiting
    if (msg.contains('429') || msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many requests. Wait a moment and try again.';
    }

    // Storage / upload errors
    if (msg.contains('StorageException') || msg.contains('storage')) {
      if (msg.contains('413') || msg.contains('too large') || msg.contains('Payload')) {
        return 'File too large. Please use a smaller image.';
      }
      return 'Upload failed. Try again.';
    }

    // Permission / RLS errors
    if (msg.contains('permission denied') ||
        msg.contains('row-level security') ||
        msg.contains('42501') ||
        msg.contains('new row violates')) {
      return 'You don\'t have permission for this action.';
    }

    // Duplicate / unique constraint
    if (msg.contains('duplicate') ||
        msg.contains('already exists') ||
        msg.contains('unique constraint') ||
        msg.contains('23505')) {
      return 'This entry already exists.';
    }

    // Not found
    if (msg.contains('404') || msg.contains('PGRST116') || msg.contains('not found')) {
      return 'Item not found. It may have been removed.';
    }

    // Generic Supabase / Postgres errors
    if (msg.contains('PostgrestException') ||
        msg.contains('PGRST') ||
        msg.contains('supabase')) {
      return 'Something went wrong. Try again.';
    }

    // Strip technical prefixes for anything else, but cap length
    final cleaned = msg
        .replaceAll('Exception: ', '')
        .replaceAll('Error: ', '')
        .replaceAll(RegExp(r'\{.*\}'), '')
        .trim();
    // If still looks technical (contains stack trace markers), use generic
    if (cleaned.contains('#0') ||
        cleaned.contains('dart:') ||
        cleaned.length > 120) {
      return 'Something went wrong. Please try again.';
    }
    return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
  }

  static void showErrorSnackBar(BuildContext context, dynamic error) {
    showSnackBar(context, errorToUserMessage(error), isError: true);
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, isSuccess: true);
  }
}
