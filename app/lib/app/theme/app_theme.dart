import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Material 3 dark theme: deep navy surfaces, teal primary, green accent.
class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.teal400,
      onPrimary: AppColors.navy950,
      secondary: AppColors.green400,
      onSecondary: AppColors.navy950,
      tertiary: AppColors.predicted,
      surface: AppColors.navy800,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.navy950,
      outline: AppColors.navy500,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.navy900,
      textTheme: AppTypography.textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy900,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.navy800,
        indicatorColor: AppColors.teal700,
        height: 68,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.navy800,
        indicatorColor: AppColors.teal700,
        selectedIconTheme: IconThemeData(color: AppColors.white),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: TextStyle(
            color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
        unselectedLabelTextStyle:
            TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.navy600,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navy700,
        selectedColor: AppColors.teal700,
        side: const BorderSide(color: AppColors.navy500),
        labelStyle: const TextStyle(
            color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: AppColors.white),
        checkmarkColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal400,
          foregroundColor: AppColors.navy950,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.navy500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal300,
          minimumSize: const Size(48, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.navy700,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.navy500),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.navy500),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal400, width: 2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.teal400,
        inactiveTrackColor: AppColors.navy600,
        thumbColor: AppColors.teal300,
        overlayColor: Color(0x332BB5B8),
        activeTickMarkColor: AppColors.navy900,
        inactiveTickMarkColor: AppColors.navy500,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navy600,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
