import '../core/utils/json_utils.dart';

/// One dated observation (acquisition) belonging to an analysis.
///
/// Per-observation *observed measurements* live here (flood extent, mean
/// line-of-sight displacement). Both are optional: unknown stays `null`.
class Observation {
  const Observation({
    required this.id,
    required this.date,
    required this.label,
    this.sensor,
    this.floodExtentKm2,
    this.meanLosDisplacementMm,
    this.qualityNote,
  });

  final String id;
  final DateTime date;

  /// Short label such as `T0`, `T1`.
  final String label;
  final String? sensor;

  /// Mapped inundated area at this date (observed).
  final double? floodExtentKm2;

  /// Mean cumulative line-of-sight displacement since the first acquisition.
  final double? meanLosDisplacementMm;
  final String? qualityNote;

  factory Observation.fromJson(Json json) => Observation(
        id: reqString(json, 'id'),
        date: reqDate(json, 'date'),
        label: optString(json, 'label') ?? reqString(json, 'id'),
        sensor: optString(json, 'sensor'),
        floodExtentKm2: optDouble(json, 'flood_extent_km2'),
        meanLosDisplacementMm: optDouble(json, 'mean_los_displacement_mm'),
        qualityNote: optString(json, 'quality_note'),
      );
}
