/// Human-readable formatting helpers. No `intl` dependency is needed.
const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `14 Jun 2025`
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// `14 Jun`
String formatDateShort(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// `2025-06-14`
String formatIsoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Whole days between two observation dates (ignores time of day).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Adds thousands separators: `12345` -> `12,345`.
String formatThousands(num value, {int decimals = 0}) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = value < 0 ? '-' : '';
  final fraction = parts.length > 1 ? '.${parts[1]}' : '';
  return '$sign$buffer$fraction';
}

/// Formats a nullable measurement. Unknown values are never invented:
/// `null` renders as [fallback].
String formatMeasure(
  double? value, {
  String unit = '',
  int decimals = 1,
  bool signed = false,
  String fallback = 'Not available',
}) {
  if (value == null) return fallback;
  final sign = signed && value > 0 ? '+' : '';
  final number = formatThousands(value, decimals: decimals);
  final suffix = unit.isEmpty ? '' : ' $unit';
  return '$sign$number$suffix';
}

String formatKm2(double? value, {bool signed = false, int decimals = 1}) =>
    formatMeasure(value, unit: 'km\u00b2', signed: signed, decimals: decimals);

String formatMm(double? value, {bool signed = false}) =>
    formatMeasure(value, unit: 'mm', signed: signed);

String formatPercent(double? value, {bool signed = false}) =>
    formatMeasure(value, unit: '%', signed: signed);
