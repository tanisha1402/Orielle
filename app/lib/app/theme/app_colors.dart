import 'package:flutter/material.dart';

/// Colour tokens: deep navy, dark teal, white and restrained green.
///
/// Text colours were chosen for at least 4.5:1 contrast on [navy800].
class AppColors {
  const AppColors._();

  // Surfaces
  static const Color navy950 = Color(0xFF050E1C);
  static const Color navy900 = Color(0xFF081426);
  static const Color navy800 = Color(0xFF0C1D36);
  static const Color navy700 = Color(0xFF12294A);
  static const Color navy600 = Color(0xFF1B3A63);
  static const Color navy500 = Color(0xFF2B4D7C);

  // Brand
  static const Color teal700 = Color(0xFF0F5C63);
  static const Color teal600 = Color(0xFF14757C);
  static const Color teal400 = Color(0xFF2BB5B8);
  static const Color teal300 = Color(0xFF5ED0D0);
  static const Color green400 = Color(0xFF5FCB8A);
  static const Color green700 = Color(0xFF1E6B45);

  // Text
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFF2F6FB);
  static const Color textSecondary = Color(0xFFA9BAD0);
  static const Color textMuted = Color(0xFF8396AF);

  // Semantic
  static const Color warning = Color(0xFFE6B450);
  static const Color danger = Color(0xFFE5736B);
  static const Color info = Color(0xFF6FB6FF);

  // Data classes (kept consistent across map, chips and charts)
  static const Color observed = Color(0xFF38BDF8);
  static const Color derived = Color(0xFFF5A524);
  static const Color predicted = Color(0xFFA78BFA);
  static const Color context = Color(0xFF9AA7B8);
  static const Color flood = Color(0xFF38BDF8);
  static const Color slope = Color(0xFFE6B450);
}
