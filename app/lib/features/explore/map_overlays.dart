import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/utils/color_utils.dart';
import '../../models/analysis_result.dart';
import '../../models/map_layer.dart';
import '../../state/providers.dart';

/// A point feature to be drawn as a marker, with its resolved legend style.
class PointOverlay {
  const PointOverlay({required this.feature, required this.color});

  final LayerFeature feature;
  final Color color;
}

/// Flutter-map primitives for the currently visible state.
class MapOverlays {
  const MapOverlays({
    required this.polygons,
    required this.polylines,
    required this.points,
  });

  final List<Polygon> polygons;
  final List<Polyline> polylines;
  final List<PointOverlay> points;
}

const Color _fallbackColor = Color(0xFF9AA7B8);

/// Decides which features are drawn and how, from pure data.
///
/// Rules (documented in docs/architecture.md):
/// * Features tied to one observation (flood extent) are drawn according to
///   [mode]: Before -> before date, After -> after date, Change -> outline of
///   the after date only.
/// * Features tied to a pair of observations (change) are drawn only in
///   Change mode, and only for the selected pair.
/// * All other features are always drawn while their layer is visible.
MapOverlays buildOverlays({
  required AnalysisResult analysis,
  required List<MapLayer> layers,
  required Set<String> visible,
  required ObservationSelection? selection,
  required CompareMode mode,
  String? selectedZoneId,
}) {
  final polygons = <Polygon>[];
  final polylines = <Polyline>[];
  final points = <PointOverlay>[];

  String? beforeId;
  String? afterId;
  if (selection != null && analysis.observations.isNotEmpty) {
    beforeId = analysis.observations[selection.beforeIndex].id;
    afterId = analysis.observations[selection.afterIndex].id;
  }
  final samePair = beforeId != null && beforeId == afterId;

  for (final layer in layers) {
    if (!visible.contains(layer.id)) continue;
    for (final f in layer.features) {
      var styleKey = f.styleKey;
      var outlineOnly = false;

      if (f.observationId != null) {
        if (beforeId == null) continue;
        switch (mode) {
          case CompareMode.before:
            if (f.observationId != beforeId) continue;
            styleKey = 'before';
          case CompareMode.after:
            if (f.observationId != afterId) continue;
            styleKey = 'after';
          case CompareMode.change:
            if (f.observationId != afterId) continue;
            styleKey = 'after';
            outlineOnly = true;
        }
      } else if (f.fromObservationId != null || f.toObservationId != null) {
        if (mode != CompareMode.change || samePair) continue;
        if (f.fromObservationId != beforeId || f.toObservationId != afterId) {
          continue;
        }
      }

      final legend = layer.legendFor(styleKey);
      final base = legend == null ? _fallbackColor : colorFromHex(legend.colorHex);
      final fillOpacity = outlineOnly ? 0.0 : (legend?.fillOpacity ?? 0.3);
      final selected = f.zoneId != null && f.zoneId == selectedZoneId;

      switch (f.kind) {
        case GeometryKind.polygon:
          polygons.add(Polygon(
            points: f.points,
            holePointsList: f.holes.isEmpty ? null : f.holes,
            color: withFraction(base, fillOpacity),
            borderColor: selected ? Colors.white : withFraction(base, 0.95),
            borderStrokeWidth: selected ? 4 : 2,
            isFilled: fillOpacity > 0,
          ));
        case GeometryKind.line:
          polylines.add(Polyline(
            points: f.points,
            strokeWidth: 3,
            color: withFraction(base, 0.95),
          ));
        case GeometryKind.point:
          points.add(PointOverlay(feature: f, color: base));
      }
    }
  }
  return MapOverlays(polygons: polygons, polylines: polylines, points: points);
}
