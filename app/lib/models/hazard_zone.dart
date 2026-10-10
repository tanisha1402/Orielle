import 'package:latlong2/latlong.dart';

import '../core/utils/json_utils.dart';
import 'hazard_type.dart';

/// Whether a zone describes something observed or something estimated.
enum ZoneBasis {
  observed('observed', 'Observed'),
  predicted('predicted', 'Predicted (preliminary)');

  const ZoneBasis(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ZoneBasis fromApi(String? value) =>
      value == 'predicted' ? ZoneBasis.predicted : ZoneBasis.observed;
}

/// A named zone of interest: a priority area, monitored slope zone, or an
/// estimated future-risk zone.
class HazardZone {
  const HazardZone({
    required this.id,
    required this.name,
    required this.hazard,
    required this.rank,
    required this.basis,
    required this.centroid,
    required this.summary,
    this.areaKm2,
    this.metricLabel,
    this.susceptibilityClass,
    this.evidence = const <String>[],
    this.valuesByObservation = const <String, double>{},
    this.dataQuality,
  });

  final String id;
  final String name;
  final HazardType hazard;

  /// 1 = highest attention. Ordering rule is supplied by the backend.
  final int rank;
  final ZoneBasis basis;
  final LatLng centroid;
  final String summary;
  final double? areaKm2;

  /// Describes what [valuesByObservation] holds, e.g.
  /// `Cumulative LOS displacement (mm)`.
  final String? metricLabel;

  /// Relative class (`low`, `moderate`, `high`) for susceptibility zones.
  /// It is a relative label, not a calibrated probability.
  final String? susceptibilityClass;
  final List<String> evidence;

  /// Observed values keyed by observation id.
  final Map<String, double> valuesByObservation;
  final String? dataQuality;

  factory HazardZone.fromJson(Json json) {
    final centroid = asJson(json['centroid'], 'centroid');
    final values = <String, double>{};
    final raw = json['values_by_observation'];
    if (raw is Map) {
      raw.forEach((Object? k, Object? v) {
        if (k is String && v is num) values[k] = v.toDouble();
      });
    }
    return HazardZone(
      id: reqString(json, 'id'),
      name: reqString(json, 'name'),
      hazard: HazardType.tryParse(optString(json, 'hazard')) ??
          HazardType.floodExpansion,
      rank: optInt(json, 'rank') ?? 99,
      basis: ZoneBasis.fromApi(optString(json, 'basis')),
      centroid:
          LatLng(reqDouble(centroid, 'lat'), reqDouble(centroid, 'lng')),
      summary: optString(json, 'summary') ?? '',
      areaKm2: optDouble(json, 'area_km2'),
      metricLabel: optString(json, 'metric_label'),
      susceptibilityClass: optString(json, 'susceptibility_class'),
      evidence: stringList(json['evidence']),
      valuesByObservation: values,
      dataQuality: optString(json, 'data_quality'),
    );
  }
}
