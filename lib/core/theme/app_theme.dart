import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color.fromRGBO(79, 48, 153, 1);
  static const Color deepPurple = Color(0xFF230261);
  static const Color tabBar = Color(0xFF300E71);
  static const Color accentMint = Color(0xFF80FFDB);
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
    scaffoldBackgroundColor: AppColors.deepPurple,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.background,
      brightness: Brightness.dark,
      primary: AppColors.background,
    ),
    fontFamily: AppTypography.family,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: AppTypography.family),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.deepPurple,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: AppTypography.body(size: 16, weight: FontWeight.w600, color: AppColors.deepPurple),
      ),
    ),
  );
}
