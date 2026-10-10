import 'package:latlong2/latlong.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/json_utils.dart';
import 'data_status.dart';
import 'hazard_type.dart';

/// Storage/transport format of a layer. Rasters are NEVER embedded in JSON.
enum LayerFormat {
  geotiff('geotiff'),
  geojson('geojson'),
  tiles('tiles'),
  png('png'),
  unknown('unknown');

  const LayerFormat(this.apiValue);
  final String apiValue;

  static LayerFormat fromApi(String? value) {
    for (final f in LayerFormat.values) {
      if (f.apiValue == value) return f;
    }
    return LayerFormat.unknown;
  }
}

/// Scientific role of a layer. Observations, derived change, predictions and
/// context must stay visually and semantically distinct.
enum LayerClassification {
  observed('observed', 'Observed'),
  derived('derived', 'Derived'),
  predicted('predicted', 'Predicted'),
  context('context', 'Context');

  const LayerClassification(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static LayerClassification fromApi(String? value) {
    for (final c in LayerClassification.values) {
      if (c.apiValue == value) return c;
    }
    return LayerClassification.context;
  }
}

enum GeometryKind { polygon, line, point }

/// One legend row. Features reference legend rows through
/// [LayerFeature.styleKey], so styling stays data-driven.
class LegendItem {
  const LegendItem({
    required this.key,
    required this.label,
    required this.colorHex,
    this.fillOpacity = 0.35,
  });

  final String key;
  final String label;
  final String colorHex;
  final double fillOpacity;

  factory LegendItem.fromJson(Json json) => LegendItem(
        key: reqString(json, 'key'),
        label: reqString(json, 'label'),
        colorHex: reqString(json, 'color'),
        fillOpacity: optDouble(json, 'fill_opacity') ?? 0.35,
      );
}

/// A vector feature. Used by inline sample layers and parsed from GeoJSON
/// features returned by the API.
class LayerFeature {
  const LayerFeature({
    required this.id,
    required this.kind,
    required this.points,
    this.holes = const <List<LatLng>>[],
    this.styleKey = 'default',
    this.observationId,
    this.fromObservationId,
    this.toObservationId,
    this.zoneId,
    this.label,
  });

  final String id;
  final GeometryKind kind;

  /// Polygon outer ring, line vertices, or a single point.
  final List<LatLng> points;
  final List<List<LatLng>> holes;
  final String styleKey;

  /// Set for features that belong to one observation (e.g. flood extent).
  final String? observationId;

  /// Set for change features that describe a pair of observations.
  final String? fromObservationId;
  final String? toObservationId;

  /// Links the feature to a [HazardZone].
  final String? zoneId;
  final String? label;

  /// Parses a GeoJSON Feature (Polygon, LineString or Point).
  ///
  /// Recognised `properties`: `id`, `style_key`, `observation_id`,
  /// `from_observation_id`, `to_observation_id`, `zone_id`, `label`.
  factory LayerFeature.fromGeoJson(Json feature, {int index = 0}) {
    final geometry = asJson(feature['geometry'], 'geometry');
    final props = feature['properties'] is Map
        ? asJson(feature['properties'], 'properties')
        : <String, dynamic>{};
    final type = geometry['type'];
    final coords = geometry['coordinates'];

    GeometryKind kind;
    List<LatLng> points;
    var holes = <List<LatLng>>[];
    switch (type) {
      case 'Polygon':
        kind = GeometryKind.polygon;
        if (coords is! List || coords.isEmpty) {
          throw const ParseException('Empty Polygon coordinates.');
        }
        points = latLngListFromPositions(coords.first);
        holes = coords.skip(1).map(latLngListFromPositions).toList();
      case 'LineString':
        kind = GeometryKind.line;
        points = latLngListFromPositions(coords);
      case 'Point':
        kind = GeometryKind.point;
        points = <LatLng>[latLngFromPosition(coords)];
      default:
        throw ParseException('Unsupported GeoJSON geometry "$type".');
    }
    return LayerFeature(
      id: optString(props, 'id') ?? 'feature_$index',
      kind: kind,
      points: points,
      holes: holes,
      styleKey: optString(props, 'style_key') ?? 'default',
      observationId: optString(props, 'observation_id'),
      fromObservationId: optString(props, 'from_observation_id'),
      toObservationId: optString(props, 'to_observation_id'),
      zoneId: optString(props, 'zone_id'),
      label: optString(props, 'label'),
    );
  }
}

/// Layer metadata (`GET /api/v1/analyses/{id}/layers`).
///
/// A layer is either *inline* ([features] non-empty: vector data that this
/// build can draw) or *remote* ([url] set: GeoTIFF / tiles / GeoJSON URL that
/// a later integration must render).
class MapLayer {
  const MapLayer({
    required this.id,
    required this.label,
    required this.format,
    required this.classification,
    required this.status,
    required this.source,
    this.hazard,
    this.url,
    this.observationDate,
    this.unavailableReason,
    this.units,
    this.description,
    this.legend = const <LegendItem>[],
    this.features = const <LayerFeature>[],
    this.defaultVisible = true,
  });

  final String id;
  final String label;
  final HazardType? hazard;
  final LayerFormat format;
  final LayerClassification classification;
  final DataStatus status;
  final String source;
  final String? url;
  final DateTime? observationDate;
  final String? unavailableReason;
  final String? units;
  final String? description;
  final List<LegendItem> legend;
  final List<LayerFeature> features;
  final bool defaultVisible;

  /// True when this build can draw the layer.
  bool get isRenderable => status.hasResult && features.isNotEmpty;

  /// Why the layer cannot be toggled on, or `null` when it can.
  String? get blockedReason {
    if (!status.hasResult) {
      return unavailableReason ?? 'This layer is not available yet.';
    }
    if (features.isEmpty) {
      return url != null
          ? 'Remote ${format.apiValue} layer - rendering is a planned '
              'integration (tiles / raster service).'
          : 'No drawable features were supplied.';
    }
    return null;
  }

  LegendItem? legendFor(String key) {
    for (final item in legend) {
      if (item.key == key) return item;
    }
    return legend.isEmpty ? null : legend.first;
  }

  factory MapLayer.fromJson(Json json) {
    final geojson = json['geojson'];
    final features = <LayerFeature>[];
    if (geojson is Map) {
      final list = asJson(geojson, 'geojson')['features'];
      if (list is List) {
        for (var i = 0; i < list.length; i++) {
          features.add(LayerFeature.fromGeoJson(asJson(list[i]), index: i));
        }
      }
    }
    // The roadmap example uses a boolean `available`; `status` wins if given.
    final status = json['status'] is String
        ? DataStatus.fromApi(optString(json, 'status'))
        : (optBool(json, 'available')
            ? DataStatus.available
            : DataStatus.notAvailable);
    return MapLayer(
      id: reqString(json, 'id'),
      label: reqString(json, 'label'),
      hazard: HazardType.tryParse(optString(json, 'hazard')),
      format: LayerFormat.fromApi(optString(json, 'format')),
      classification:
          LayerClassification.fromApi(optString(json, 'classification')),
      status: status,
      source: optString(json, 'source') ?? 'Source not stated',
      url: optString(json, 'url'),
      observationDate: optDate(json, 'observation_date'),
      unavailableReason: optString(json, 'unavailable_reason'),
      units: optString(json, 'units'),
      description: optString(json, 'description'),
      legend: mapList(json['legend'], LegendItem.fromJson),
      features: features,
      defaultVisible: optBool(json, 'default_visible', fallback: true),
    );
  }
}
