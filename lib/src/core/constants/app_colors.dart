import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── BRAND ───
  static const Color brandTeal = Color(0xFF0F6F69);
  static const Color brandTealLight = Color(0xFFE6F5F3);
  static const Color brandTealDark = Color(0xFF0A4F4A);
  static const Color brandOrange = Color(0xFFD97706);
  static const Color brandOrangeLight = Color(0xFFFEF3C7);
  static const Color brandOrangeDark = Color(0xFFB45309);

  // ─── BACKGROUNDS ───
  static const Color scaffoldBg = Color(0xFFF5F5F0);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFFFAFAFA);
  static Color surfaceGlass = Colors.white.withValues(alpha: 0.85);
  static Color surfaceGlassBorder = Colors.white.withValues(alpha: 0.40);

  // ─── TEXT ───
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF5A6178);
  static const Color textTertiary = Color(0xFF8E95A9);
  static const Color textOnTeal = Colors.white;
  static const Color textOnCard = Color(0xFF1A1A2E);

  // ─── BORDERS & DIVIDERS ───
  static const Color borderDefault = Color(0xFFE0E4EA);
  static const Color borderFocus = Color(0xFF0F6F69);
  static const Color divider = Color(0xFFF0F1F3);

  // ─── SEMANTIC ───
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFEFF6FF);

  // ─── GRADIENTS ───
  static const LinearGradient tranzfortGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandTeal, brandOrange],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get superLoadGlow => [
        BoxShadow(
          color: brandOrange.withValues(alpha: 0.25),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ];
}
