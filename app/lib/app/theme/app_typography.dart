import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale. Uses the platform default family so the app works fully
/// offline; swap `fontFamily` in [AppTheme] if you bundle a font.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    return base
        .copyWith(
          displaySmall: const TextStyle(
              fontSize: 30, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.5),
          headlineSmall: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.2),
          titleLarge: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w700, height: 1.3),
          titleMedium: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
          titleSmall: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          bodySmall: const TextStyle(fontSize: 12.5, height: 1.4),
          labelLarge: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          labelMedium: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          labelSmall: const TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );
  }

  /// Large measurement values: tabular figures keep columns aligned.
  static const TextStyle metricValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: AppColors.textPrimary,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}
