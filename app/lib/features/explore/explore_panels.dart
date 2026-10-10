import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/ui_extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/data_status.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/map_layer.dart';
import '../../state/providers.dart';
import '../common/observation_selector.dart';

/// Side / bottom panel of the Explore screen.
class ExplorePanels extends ConsumerWidget {
  const ExplorePanels({super.key, required this.data});

  final ExploreData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = data.analysis;
    final override = ref.watch(layerVisibilityOverrideProvider(analysis.id));
    final visible = effectiveVisibleLayers(data.layers, override);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (analysis.isSample) ...<Widget>[
          const SampleDataBanner(),
          const SizedBox(height: 12),
        ],
        // Real records without bundled geometry: say so under the map, not
        // on top of it, so the map and its markers stay fully visible.
        if (!analysis.isSample &&
            data.layers.isEmpty &&
            analysis.status != DataStatus.notAvailable) ...<Widget>[
          const UnavailablePanel(
            compact: true,
            title: 'No overlays to show',
            message: 'No flood outlines are bundled for this record. '
                'Numbered markers are zone reference points. A circle has '
                'the same area as the reported value; it is not the flood '
                'shape.',
          ),
          const SizedBox(height: 12),
        ],
        if (analysis.observations.isNotEmpty) ...<Widget>[
          TimelineCard(analysis: analysis),
          const SizedBox(height: 12),
        ],
        ZonesCard(analysis: analysis),
        const SizedBox(height: 12),
        if (data.layers.isNotEmpty) ...<Widget>[
          LayersCard(analysis: analysis, layers: data.layers, visible: visible),
          const SizedBox(height: 12),
          LegendCard(layers: data.layers, visible: visible),
          const SizedBox(height: 12),
        ],
        SourcesCard(analysis: analysis, layers: data.layers, visible: visible),
      ],
    );
  }
}

/// Observation timeline and before/after comparison.
class TimelineCard extends ConsumerWidget {
  const TimelineCard({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sel = ref.watch(observationSelectionProvider);
    final mode = ref.watch(compareModeProvider);
    final isFlood = analysis.hazard == HazardType.floodExpansion;
    final obs = analysis.observations;

    Widget summary = const SizedBox.shrink();
    if (sel != null) {
      final before = obs[sel.beforeIndex];
      final after = obs[sel.afterIndex];
      if (isFlood) {
        if (sel.beforeIndex == sel.afterIndex) {
          summary = Text(
            'Choose two different dates to compare them.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warning),
          );
        } else {
          final stat = analysis.changeFor(before.id, after.id);
          summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${formatDate(before.date)} \u2192 ${formatDate(after.date)} '
                '(${daysBetween(before.date, after.date)} days)',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                stat?.netChangeKm2 == null
                    ? 'Net change: not available for this pair of dates.'
                    : 'Net mapped change: ${formatKm2(stat!.netChangeKm2, signed: true)}',
                style: theme.textTheme.titleSmall,
              ),
            ],
          );
        }
      } else {
        summary = Text(
          'Zone values are cumulative line-of-sight displacement as of '
          '${formatDate(after.date)} (since ${formatDate(obs.first.date)}).',
          style: theme.textTheme.bodyMedium,
        );
      }
    }

    return SectionCard(
      title: 'Observation timeline',
      subtitle: isFlood
          ? 'Drag the handles to choose the before and after dates'
          : 'Drag to choose the "as of" date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ObservationSelector(analysis: analysis),
          if (isFlood) ...<Widget>[
            const SizedBox(height: 12),
            SegmentedButton<CompareMode>(
              key: const Key('compare-mode'),
              showSelectedIcon: false,
              segments: <ButtonSegment<CompareMode>>[
                for (final m in CompareMode.values)
                  ButtonSegment<CompareMode>(value: m, label: Text(m.label)),
              ],
              selected: <CompareMode>{mode},
              onSelectionChanged: (Set<CompareMode> v) =>
                  ref.read(compareModeProvider.notifier).state = v.first,
            ),
          ],
          const SizedBox(height: 12),
          summary,
        ],
      ),
    );
  }
}

/// Zone chooser and selected-zone details.
class ZonesCard extends ConsumerWidget {
  const ZonesCard({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectionProvider.select((s) => s.zoneId));
    final zone = analysis.zoneById(selectedId);
    final sel = ref.watch(observationSelectionProvider);

    if (analysis.zones.isEmpty) {
      return const SectionCard(
        title: 'Zones',
        child: UnavailablePanel(
          compact: true,
          title: 'No zones listed',
          message: 'The analysis record does not list priority zones.',
        ),
      );
    }

    return SectionCard(
      title: 'Zones',
      subtitle: 'Tap a numbered marker on the map or choose a zone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final z in analysis.zonesByRank)
                ChoiceChip(
                  key: Key('zone-chip-${z.id}'),
                  label: Text('${z.rank}  ${_short(z.name)}'),
                  selected: z.id == selectedId,
                  onSelected: (bool on) => ref
                      .read(selectionProvider.notifier)
                      .selectZone(on ? z.id : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (zone == null)
            Text(
              'No zone selected.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            )
          else
            _ZoneDetails(analysis: analysis, zone: zone, selection: sel),
        ],
      ),
    );
  }

  String _short(String name) {
    final i = name.indexOf(' - ');
    return i > 0 ? name.substring(0, i) : name;
  }
}

class _ZoneDetails extends StatelessWidget {
  const _ZoneDetails({
    required this.analysis,
    required this.zone,
    required this.selection,
  });

  final AnalysisResult analysis;
  final HazardZone zone;
  final ObservationSelection? selection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double? value;
    if (selection != null) {
      final obsId = analysis.observations[selection!.afterIndex].id;
      value = zone.valuesByObservation[obsId];
    }
    return Container(
      key: const Key('zone-details'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: withFraction(zone.basis.color, 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(zone.name, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          BasisChip(zone.basis),
          const SizedBox(height: 8),
          Text(zone.summary, style: theme.textTheme.bodyMedium),
          if (zone.metricLabel != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '${zone.metricLabel}: ${formatMeasure(value, decimals: 1, signed: (zone.metricLabel ?? '').toLowerCase().contains('displacement'), fallback: 'not available at this date')}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (zone.areaKm2 != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Zone footprint: ${formatKm2(zone.areaKm2)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
          if (zone.evidence.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            BulletList(zone.evidence.take(2).toList()),
          ],
          Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton(
                onPressed: () => context.go(AppRoutes.risk),
                child: const Text('Risk analysis'),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.impact),
                child: const Text('Impact'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Layer visibility toggles with classification and unavailable reasons.
class LayersCard extends ConsumerWidget {
  const LayersCard({
    super.key,
    required this.analysis,
    required this.layers,
    required this.visible,
  });

  final AnalysisResult analysis;
  final List<MapLayer> layers;
  final Set<String> visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    void toggle(String id, bool on) {
      final next = Set<String>.of(visible);
      if (on) {
        next.add(id);
      } else {
        next.remove(id);
      }
      ref.read(layerVisibilityOverrideProvider(analysis.id).notifier).state =
          next;
    }

    return SectionCard(
      title: 'Map layers',
      subtitle: 'Observed, derived and predicted layers are kept distinct',
      child: Column(
        children: <Widget>[
          for (final layer in layers)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Switch(
                    key: Key('layer-switch-${layer.id}'),
                    value: visible.contains(layer.id),
                    onChanged: layer.blockedReason == null
                        ? (bool on) => toggle(layer.id, on)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(layer.label, style: theme.textTheme.titleSmall),
                              ClassificationChip(layer.classification),
                              if (layer.status != DataStatus.available)
                                StatusChip(layer.status),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            layer.blockedReason ?? layer.description ?? layer.source,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class LegendCard extends StatelessWidget {
  const LegendCard({super.key, required this.layers, required this.visible});

  final List<MapLayer> layers;
  final Set<String> visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final layer in layers) {
      if (!visible.contains(layer.id)) continue;
      for (final item in layer.legend) {
        final color = colorFromHex(item.colorHex);
        rows.add(Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 18,
              height: 14,
              decoration: BoxDecoration(
                color: withFraction(color, item.fillOpacity.clamp(0.25, 1.0).toDouble()),
                border: Border.all(color: color, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(item.label, style: theme.textTheme.bodySmall)),
          ],
        ));
      }
    }
    return SectionCard(
      title: 'Legend',
      child: rows.isEmpty
          ? Text('No visible layer has a legend.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary))
          : Wrap(spacing: 16, runSpacing: 8, children: rows),
    );
  }
}

class SourcesCard extends StatelessWidget {
  const SourcesCard({
    super.key,
    required this.analysis,
    required this.layers,
    required this.visible,
  });

  final AnalysisResult analysis;
  final List<MapLayer> layers;
  final Set<String> visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = <String>[
      for (final s in analysis.dataSources)
        s.note == null ? s.label : '${s.label} - ${s.note}',
      for (final l in layers)
        if (visible.contains(l.id)) 'Layer "${l.label}": ${l.source}',
    ];
    return SectionCard(
      title: 'Sources and attribution',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (sources.isEmpty)
            Text('No sources recorded.', style: theme.textTheme.bodySmall)
          else
            BulletList(sources),
          const SizedBox(height: 6),
          Text(
            'Basemap tiles: see the attribution on the map. Analysis '
            '${analysis.id}${analysis.processingVersion == null ? '' : ', processing ${analysis.processingVersion}'}.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
