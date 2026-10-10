import 'package:latlong2/latlong.dart';

import '../core/utils/json_utils.dart';
import 'hazard_type.dart';

/// A monitored region (`GET /api/v1/areas`).
class StudyArea {
  const StudyArea({
    required this.id,
    required this.name,
    required this.region,
    required this.center,
    required this.zoom,
    required this.supportedHazards,
    this.description,
    this.boundary = const <LatLng>[],
    this.isSample = false,
  });

  final String id;
  final String name;
  final String region;
  final LatLng center;
  final double zoom;
  final List<HazardType> supportedHazards;
  final String? description;

  /// Optional outline of the study area (closed ring, not repeated point).
  final List<LatLng> boundary;
  final bool isSample;

  factory StudyArea.fromJson(Json json) {
    final centerJson = asJson(json['center'], 'center');
    return StudyArea(
      id: reqString(json, 'id'),
      name: reqString(json, 'name'),
      region: optString(json, 'region') ?? '',
      center: LatLng(reqDouble(centerJson, 'lat'), reqDouble(centerJson, 'lng')),
      zoom: optDouble(json, 'zoom') ?? 10,
      supportedHazards: stringList(json['hazards'])
          .map(HazardType.tryParse)
          .whereType<HazardType>()
          .toList(growable: false),
      description: optString(json, 'description'),
      boundary: json['boundary'] == null
          ? const <LatLng>[]
          : latLngListFromPositions(json['boundary']),
      isSample: optBool(json, 'is_sample'),
    );
  }
}
