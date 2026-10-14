import 'package:flutter/material.dart';

/// Brand: dark green primary (#01503A), golden yellow accent (#CC9C20).
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF01503A);
  static const Color accentGold = Color(0xFFCC9C20);

  /// Scaffold / app chrome (kept for existing call sites).
  static const Color deepPurple = primary;
  static const Color accentMint = accentGold;
  static const Color background = primary;

  static const Color tabBar = Color(0xFF013D2E);

  /// Cards, sheets, inputs on primary background.
  static const Color surface = Color(0xFF024732);
  static const Color surfaceElevated = Color(0xFF036B52);
  static const Color sheet = Color(0xFF034028);
  static const Color border = Color(0xFF047A5C);

  static const Color mutedOnDark = Color(0xFF8FB5A8);
  static const Color gradientStart = Color(0xFF027656);
  static const Color gradientEnd = Color(0xFF012A1F);
  static const Color gradientAccent = Color(0xFFE8B84A);

  static const Color success = Color(0xFF3ADB76);
  static const Color warning = Color(0xFFFFAE00);
  static const Color white = Colors.white;
  static const Color muted = Color(0xFF888888);
}

class AppTypography {
  AppTypography._();

  static const String family = 'DigretoNeue';

  static TextStyle headline({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.white,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.2,
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.white,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

ThemeData buildZapTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.accentGold,
    ),
    fontFamily: AppTypography.family,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: AppTypography.family),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: AppTypography.body(
          size: 16,
          weight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}
