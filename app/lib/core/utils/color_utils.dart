import 'dart:ui' show Color;

/// Parses `#RRGGBB` (or `RRGGBB`) into an opaque [Color].
/// Falls back to [fallback] for malformed input.
Color colorFromHex(String hex, {Color fallback = const Color(0xFF9AA7B8)}) {
  var clean = hex.trim();
  if (clean.startsWith('#')) clean = clean.substring(1);
  if (clean.length != 6) return fallback;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

/// Returns [color] with an alpha channel of [fraction] (0..1).
Color withFraction(Color color, double fraction) {
  final clamped = fraction.clamp(0.0, 1.0);
  return color.withAlpha((clamped * 255).round());
}
