import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Central design tokens for GYMMER — modern-minimal, true-black.
///
/// Every screen must read colors from here instead of hardcoding
/// `Color(0xFF...)` values. `accent` is a signal color only: completed sets,
/// rest timer, active tab indicator, and the "workout in progress" dot.
abstract final class AppColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF121214);
  static const surfaceHigh = Color(0xFF1C1C1F);
  static const hairline = Color(0xFF242428);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9E9EA7);
  static const textTertiary = Color(0xFF5E5E66);
  static const accent = Color(0xFF7DFF8A);
  static const danger = Color(0xFFFF5A5A);
  static const musclePrimary = Color(0xFFD82020);
  static const muscleSecondary = Color(0xFFFF9A7A);
}

/// Shared shape constants.
abstract final class AppRadii {
  static const card = 16.0;
  static const input = 12.0;
}

/// Monospaced-figure style for KG / reps / set numbers / timers.
const kNumericStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w600,
  fontFeatures: [FontFeature.tabularFigures()],
);

ThemeData buildGymmerTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: Colors.white,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.copyWith(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.hairline,
      error: AppColors.danger,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 15, height: 1.35),
      bodySmall: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      hintStyle: const TextStyle(color: AppColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: Colors.white),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bg,
      indicatorColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
