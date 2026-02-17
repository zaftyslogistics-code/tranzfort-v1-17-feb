import 'package:flutter/material.dart';
import 'app_colors.dart';

/// All text styles use the Inter font family set by the theme.
/// Avoids per-call GoogleFonts.inter() overhead.
class AppTypography {
  AppTypography._();

  static const _fontFamily = 'Inter';

  static TextStyle get h1Hero => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 34 / 26,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2Section => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3Subsection => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 24 / 17,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.2,
        color: AppColors.textTertiary,
      );

  static TextStyle get overline => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      );

  static TextStyle get buttonLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: Colors.white,
      );

  static TextStyle get buttonSmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: AppColors.brandTeal,
      );

  static TextStyle get number => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 28 / 20,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      );
}
