import 'package:latlong2/latlong.dart';

import '../errors/app_exception.dart';

/// Shorthand for decoded JSON objects.
typedef Json = Map<String, dynamic>;

/// Casts [value] to a JSON object or throws a [ParseException].
Json asJson(Object? value, [String context = 'object']) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw ParseException('Expected a JSON object for $context.');
}

String reqString(Json json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw ParseException('Missing or invalid string field "$key".');
}

String? optString(Json json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

double? optDouble(Json json, String key) {
  final value = json[key];
  return value is num ? value.toDouble() : null;
}

double reqDouble(Json json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw ParseException('Missing or invalid number field "$key".');
}

int? optInt(Json json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : null;
}

bool optBool(Json json, String key, {bool fallback = false}) {
  final value = json[key];
  return value is bool ? value : fallback;
}

DateTime? optDate(Json json, String key) {
  final value = json[key];
  return value is String ? DateTime.tryParse(value) : null;
}

DateTime reqDate(Json json, String key) {
  final value = optDate(json, key);
  if (value != null) return value;
  throw ParseException('Missing or invalid date field "$key".');
}

/// Maps a JSON array of objects. A missing/null field yields an empty list.
List<T> mapList<T>(Object? value, T Function(Json json) convert) {
  if (value is! List) return <T>[];
  return value
      .map((Object? e) => convert(asJson(e)))
      .toList(growable: false);
}

List<String> stringList(Object? value) {
  if (value is! List) return <String>[];
  return value.whereType<String>().toList(growable: false);
}

/// Parses a GeoJSON position `[longitude, latitude]` into a [LatLng].
LatLng latLngFromPosition(Object? position) {
  if (position is List && position.length >= 2) {
    final lng = position[0];
    final lat = position[1];
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
  }
  throw const ParseException('Invalid GeoJSON position.');
}

/// Parses a GeoJSON ring/line (`[[lng, lat], ...]`).
List<LatLng> latLngListFromPositions(Object? positions) {
  if (positions is! List) {
    throw const ParseException('Invalid GeoJSON coordinate list.');
  }
  return positions.map(latLngFromPosition).toList(growable: false);
}
