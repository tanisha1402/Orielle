import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo_utils.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/data_status.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/map_layer.dart';
import '../../models/study_area.dart';
import '../../state/providers.dart';
import 'map_overlays.dart';

/// Interactive map for one analysis. Create it with a key that includes the
/// analysis id so camera and tile-error state reset when the selection changes.
class ExploreMap extends ConsumerStatefulWidget {
  const ExploreMap({super.key, required this.data});

  final ExploreData data;

  @override
  ConsumerState<ExploreMap> createState() => _ExploreMapState();
}

class _ExploreMapState extends ConsumerState<ExploreMap> {
  final MapController _controller = MapController();
  final ValueNotifier<int> _tileErrors = ValueNotifier<int>(0);

  StudyArea? get _area => ref.read(effectiveAreaProvider).valueOrNull;

  void _zoomBy(double delta) {
    final camera = _controller.camera;
    final next = (camera.zoom + delta)
        .clamp(MapConfig.minZoom, MapConfig.maxZoom)
        .toDouble();
    _controller.move(camera.center, next);
  }

  void _recenter() {
    final area = _area;
    if (area == null) return;
    _controller.move(area.center, area.zoom);
  }

  void _toggleBasemap() {
    final notifier = ref.read(basemapModeProvider.notifier);
    if (notifier.state == BasemapMode.online) {
      notifier.state = BasemapMode.schematic;
    } else {
      _tileErrors.value = 0;
      notifier.state = BasemapMode.online;
    }
  }

  void _handleTap(LatLng point, Set<String> visible) {
    String? hit;
    for (final layer in widget.data.layers) {
      if (!visible.contains(layer.id)) continue;
      for (final f in layer.features) {
        if (f.zoneId != null &&
            f.kind == GeometryKind.polygon &&
            pointInPolygon(point, f.points)) {
          hit = f.zoneId;
        }
      }
    }
    ref.read(selectionProvider.notifier).selectZone(hit);
  }

  @override
  void dispose() {
    _tileErrors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.data.analysis;
    final layers = widget.data.layers;
    final area = ref.watch(effectiveAreaProvider).valueOrNull;
    final override = ref.watch(layerVisibilityOverrideProvider(analysis.id));
    final visible = effectiveVisibleLayers(layers, override);
    final selection = ref.watch(observationSelectionProvider);
    final mode = ref.watch(compareModeProvider);
    final selectedZoneId = ref.watch(selectionProvider.select((s) => s.zoneId));
    final basemap = ref.watch(basemapModeProvider);

    final overlays = buildOverlays(
      analysis: analysis,
      layers: layers,
      visible: visible,
      selection: selection,
      mode: mode,
      selectedZoneId: selectedZoneId,
    );

    final markers = <Marker>[
      for (final p in overlays.points)
        Marker(
          point: p.feature.points.first,
          width: 30,
          height: 30,
          child: Tooltip(
            message: p.feature.label ?? p.feature.styleKey,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.navy900,
                shape: BoxShape.circle,
                border: Border.all(color: p.color, width: 2),
              ),
              child: Icon(_iconFor(p.feature.styleKey), size: 16, color: p.color),
            ),
          ),
        ),
      // Records without bundled layers (real historical figures) still show
      // their zones as markers at their reference points.
      if (visible.contains('priority_zones') || layers.isEmpty)
        for (final z in analysis.zones)
          Marker(
            point: z.centroid,
            width: 36,
            height: 36,
            child: _ZoneBadge(
              zone: z,
              selected: z.id == selectedZoneId,
              onTap: () => ref.read(selectionProvider.notifier).selectZone(
                  z.id == selectedZoneId ? null : z.id),
            ),
          ),
    ];

    // Real records without geometry: draw each zone's reported area as an
    // equal-area circle at its reference point. This is a symbol, NOT the
    // shape of the flood or of the zone, and the banner below says so.
    final circles = <CircleMarker>[];
    if (layers.isEmpty &&
        selection != null &&
        analysis.hazard == HazardType.floodExpansion &&
        analysis.observations.isNotEmpty) {
      final idx = mode == CompareMode.before
          ? selection.beforeIndex
          : selection.afterIndex;
      final obsId = analysis.observations[idx].id;
      for (final z in analysis.zones) {
        final values = z.valuesByObservation;
        final v = values[obsId] ?? (values.length == 1 ? values.values.first : null);
        if (v == null || v <= 0) continue;
        final isSelected = z.id == selectedZoneId;
        circles.add(CircleMarker(
          point: z.centroid,
          radius: math.sqrt(v * 1000000 / math.pi),
          useRadiusInMeter: true,
          color: withFraction(AppColors.teal300, 0.22),
          borderColor: isSelected ? Colors.white : AppColors.teal300,
          borderStrokeWidth: isSelected ? 3 : 1.5,
        ));
      }
    }

    final center = area?.center ?? LatLng(23.7, 90.4);
    final zoom = area?.zoom ?? 7;

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            backgroundColor: AppColors.navy950,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (TapPosition tapPosition, LatLng point) =>
                _handleTap(point, visible),
          ),
          children: <Widget>[
            if (basemap == BasemapMode.online)
              TileLayer(
                urlTemplate: MapConfig.tileUrlTemplate,
                userAgentPackageName: MapConfig.userAgentPackageName,
                maxNativeZoom: MapConfig.tileMaxNativeZoom,
                errorTileCallback: (tile, error, stackTrace) {
                  _tileErrors.value = _tileErrors.value + 1;
                },
              ),
            if (area != null && area.boundary.length >= 3)
              PolygonLayer(polygons: <Polygon>[
                Polygon(
                  points: area.boundary,
                  color: const Color(0x00000000),
                  borderColor: AppColors.teal300,
                  borderStrokeWidth: 1.5,
                  isFilled: false,
                ),
              ]),
            PolygonLayer(polygons: overlays.polygons),
            PolylineLayer(polylines: overlays.polylines),
            if (circles.isNotEmpty) CircleLayer(circles: circles),
            MarkerLayer(markers: markers),
            if (basemap == BasemapMode.online)
              RichAttributionWidget(
                attributions: <SourceAttribution>[
                  TextSourceAttribution(MapConfig.tileAttribution),
                ],
              ),
          ],
        ),
        // Status badges (top-left).
        Positioned(
          top: 8,
          left: 8,
          right: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (analysis.isSample)
                const Tag(
                  label: 'SAMPLE OVERLAYS - not satellite-derived',
                  color: AppColors.warning,
                  icon: Icons.science_outlined,
                ),
              const SizedBox(height: 6),
              _CompareBadge(analysis: analysis, selection: selection, mode: mode),
            ],
          ),
        ),
        // Tools (top-right).
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            children: <Widget>[
              _MapButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: () => _zoomBy(1),
              ),
              _MapButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: () => _zoomBy(-1),
              ),
              _MapButton(
                icon: Icons.my_location,
                tooltip: 'Recenter on study area',
                onPressed: _recenter,
              ),
              _MapButton(
                key: const Key('basemap-toggle'),
                icon: basemap == BasemapMode.online
                    ? Icons.grid_on
                    : Icons.public,
                tooltip: basemap == BasemapMode.online
                    ? 'Switch to offline schematic basemap'
                    : 'Switch to online basemap',
                onPressed: _toggleBasemap,
              ),
            ],
          ),
        ),
        if (basemap == BasemapMode.schematic)
          const Positioned(
            right: 8,
            bottom: 8,
            child: Tag(
              label: 'Schematic basemap (offline) - no map data',
              color: AppColors.textSecondary,
            ),
          ),
        // Tile failure banner.
        Positioned(
          left: 8,
          right: 8,
          bottom: 30,
          child: ValueListenableBuilder<int>(
            valueListenable: _tileErrors,
            builder: (BuildContext context, int errors, Widget? child) {
              if (basemap != BasemapMode.online ||
                  errors < MapConfig.tileErrorThreshold) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.cloud_off, color: AppColors.warning),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Basemap tiles are not loading. '
                          'Overlays still work.'),
                    ),
                    TextButton(
                      onPressed: _toggleBasemap,
                      child: const Text('Use schematic'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (analysis.status == DataStatus.notAvailable)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: UnavailablePanel(
                title: 'No overlays to show',
                message: analysis.statusNote ??
                    'This analysis has no map layers yet.',
              ),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String styleKey) {
    switch (styleKey) {
      case 'school':
        return Icons.school;
      case 'community':
        return Icons.home;
      default:
        return Icons.place;
    }
  }
}

class _ZoneBadge extends StatelessWidget {
  const _ZoneBadge({
    required this.zone,
    required this.selected,
    required this.onTap,
  });

  final HazardZone zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        zone.basis == ZoneBasis.observed ? AppColors.white : AppColors.predicted;
    return Semantics(
      button: true,
      label: 'Zone ${zone.rank}: ${zone.name}',
      child: GestureDetector(
        key: Key('zone-marker-${zone.id}'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? color : AppColors.navy900,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: selected ? 3 : 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '${zone.rank}',
            style: TextStyle(
              color: selected ? AppColors.navy950 : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareBadge extends StatelessWidget {
  const _CompareBadge({
    required this.analysis,
    required this.selection,
    required this.mode,
  });

  final AnalysisResult analysis;
  final ObservationSelection? selection;
  final CompareMode mode;

  @override
  Widget build(BuildContext context) {
    final sel = selection;
    if (sel == null || analysis.observations.isEmpty) {
      return const SizedBox.shrink();
    }
    final obs = analysis.observations;
    final before = obs[sel.beforeIndex].date;
    final after = obs[sel.afterIndex].date;
    String label;
    if (analysis.hazard == HazardType.slopeDeformation) {
      label = 'Values as of ${formatDate(after)}';
    } else {
      switch (mode) {
        case CompareMode.before:
          label = 'Before: ${formatDate(before)}';
        case CompareMode.after:
          label = 'After: ${formatDate(after)}';
        case CompareMode.change:
          label = before == after
              ? 'Pick two different dates'
              : 'Change: ${formatDateShort(before)} \u2192 ${formatDate(after)}';
      }
    }
    return Tag(label: label, color: AppColors.teal300, icon: Icons.event);
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.navy800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.navy500),
        ),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
