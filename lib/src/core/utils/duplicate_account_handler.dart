import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'validators.dart';

/// Professional duplicate account error handling for signup flows
class DuplicateAccountHandler {
  DuplicateAccountHandler._();

  /// Detects if an error is related to duplicate email/mobile
  static bool _isDuplicateError(dynamic error) {
    final message = error.toString().toLowerCase();
    
    // Supabase doesn't throw explicit duplicate errors for signup
    // But we can detect patterns in error messages
    return message.contains('duplicate') ||
           message.contains('already exists') ||
           message.contains('already registered') ||
           message.contains('user already exists') ||
           message.contains('unique constraint') ||
           message.contains('violates unique constraint');
  }

  /// Detects if signup response indicates existing user
  static bool _isExistingUserSignup(AuthResponse response) {
    // Supabase returns user object for existing emails but no session
    return response.user != null && response.session == null;
  }

  /// Creates a user-friendly dialog for duplicate account scenarios
  static Future<void> showDuplicateAccountDialog(
    BuildContext context, {
    required String email,
    required String mobile,
    bool isEmailDuplicate = false,
    bool isMobileDuplicate = false,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.brandTeal,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Account Already Exists',
              style: AppTypography.h3Subsection,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEmailDuplicate) ...[
              Text(
                'The email address',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                email,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brandTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'is already registered in our system.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (isMobileDuplicate) ...[
              Text(
                'The mobile number',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                Validators.displayIndianMobile(mobile),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.brandTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'is already registered in our system.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Go to Login
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              GoRouter.of(ctx).go('/login');
            },
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Go to Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Forgot Password
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              GoRouter.of(ctx).go('/forgot-password');
            },
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('Reset Password'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          // Cancel
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Handles duplicate account detection and shows appropriate dialog
  static Future<bool> handleDuplicateAccount(
    BuildContext context, {
    AuthResponse? signupResponse,
    dynamic error,
    required String email,
    required String mobile,
  }) async {
    // Check if signup response indicates existing user
    if (signupResponse != null && _isExistingUserSignup(signupResponse)) {
      await showDuplicateAccountDialog(
        context,
        email: email,
        mobile: mobile,
        isEmailDuplicate: true, // Most common case
      );
      return true; // Handled as duplicate
    }

    // Check if error indicates duplicate
    if (error != null && _isDuplicateError(error)) {
      final message = error.toString().toLowerCase();
      final isEmailDup = message.contains('email');
      final isMobileDup = message.contains('mobile') || message.contains('phone');
      
      await showDuplicateAccountDialog(
        context,
        email: email,
        mobile: mobile,
        isEmailDuplicate: isEmailDup,
        isMobileDuplicate: isMobileDup,
      );
      return true; // Handled as duplicate
    }

    return false; // Not a duplicate error
  }
}
