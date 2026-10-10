import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_extensions.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/explanation_result.dart';
import '../../models/hazard_type.dart';
import '../../models/map_layer.dart';
import '../../models/validation_result.dart';
import '../../state/providers.dart';
import '../common/observation_selector.dart';
import '../common/zone_utils.dart';
import 'risk_charts.dart';

/// Header: analysis title and status.
class RiskHeader extends StatelessWidget {
  const RiskHeader({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(analysis.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            StatusChip(analysis.status, prefix: 'Analysis'),
            if (analysis.isSample) const SampleDataBadge(),
          ],
        ),
        if (analysis.isSample) ...<Widget>[
          const SizedBox(height: 10),
          const SampleDataBanner(),
        ],
      ],
    );
  }
}

/// Observed flood change between the selected dates.
class FloodChangeSection extends ConsumerWidget {
  const FloodChangeSection({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sel = ref.watch(observationSelectionProvider);
    final obs = analysis.observations;
    Widget body;
    if (sel == null || obs.length < 2) {
      body = const UnavailablePanel(
        compact: true,
        title: 'Not enough observations',
        message: 'Two or more dated observations are needed to measure change.',
      );
    } else {
      final before = obs[sel.beforeIndex];
      final after = obs[sel.afterIndex];
      final stat = analysis.changeFor(before.id, after.id);
      Widget stats;
      if (sel.beforeIndex == sel.afterIndex) {
        stats = const UnavailablePanel(
          compact: true,
          title: 'Choose two different dates',
          message: 'Drag the timeline handles apart to compare observations.',
        );
      } else if (stat == null) {
        stats = const UnavailablePanel(
          compact: true,
          title: 'No statistics for this pair',
          message: 'The analysis record has no pre-computed change for these '
              'two dates. The app does not calculate it itself.',
        );
      } else {
        final net = stat.netChangeKm2;
        final Tag indicator;
        if (net == null) {
          indicator = const Tag(
              label: 'Change not available', color: AppColors.textSecondary);
        } else if (net > 0) {
          indicator = const Tag(
              label: 'Expansion of mapped flooding',
              color: AppColors.derived,
              icon: Icons.trending_up);
        } else if (net < 0) {
          indicator = const Tag(
              label: 'Contraction of mapped flooding',
              color: AppColors.green400,
              icon: Icons.trending_down);
        } else {
          indicator = const Tag(
              label: 'No net change',
              color: AppColors.textSecondary,
              icon: Icons.trending_flat);
        }
        stats = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TileWrap(
              minTileWidth: 140,
              children: <Widget>[
                MetricTile(
                  label: 'Flooded area before',
                  value: formatKm2(stat.areaBeforeKm2),
                  caption: formatDate(before.date),
                ),
                MetricTile(
                  label: 'Flooded area after',
                  value: formatKm2(stat.areaAfterKm2),
                  caption: formatDate(after.date),
                ),
                MetricTile(
                  key: const Key('net-change-tile'),
                  label: 'Net change',
                  value: formatKm2(net, signed: true),
                  caption: stat.percentChange == null
                      ? null
                      : '${formatPercent(stat.percentChange, signed: true)} vs before',
                  valueColor: net == null
                      ? null
                      : (net > 0
                          ? AppColors.derived
                          : (net < 0 ? AppColors.green400 : null)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            indicator,
          ],
        );
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Observation period', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            sel.beforeIndex == sel.afterIndex
                ? formatDate(before.date)
                : '${formatDate(before.date)} \u2192 ${formatDate(after.date)} '
                    '(${daysBetween(before.date, after.date)} days)',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          ObservationSelector(analysis: analysis),
          const SizedBox(height: 14),
          stats,
          const SizedBox(height: 16),
          Text('Mapped flood extent per observation',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          FloodExtentChart(analysis: analysis, selection: sel),
          const SizedBox(height: 10),
          Text(
            'Net mapped area change is the difference between two observed '
            'extents. It does not prove that flooding will continue to '
            'expand.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
    }
    return SectionCard(
      title: 'Observed flood change',
      accent: AppColors.observed,
      trailing: const ClassificationChip(LayerClassification.observed),
      child: body,
    );
  }
}

/// Observed slope deformation (kept separate from susceptibility).
class DeformationSection extends ConsumerWidget {
  const DeformationSection({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = analysis.deformation;
    final sel = ref.watch(observationSelectionProvider);
    if (d == null) {
      return const SectionCard(
        title: 'Observed slope deformation',
        child: UnavailablePanel(
          compact: true,
          title: 'No deformation measurements',
          message: 'The analysis record has no line-of-sight displacement '
              'summary.',
        ),
      );
    }
    final first = analysis.firstObservation;
    final last = analysis.latestObservation;
    return SectionCard(
      title: 'Observed slope deformation',
      accent: AppColors.observed,
      trailing: const ClassificationChip(LayerClassification.observed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (first != null && last != null)
            Text(
              'Observation period: ${formatDate(first.date)} \u2192 '
              '${formatDate(last.date)} (${analysis.observations.length} acquisitions)',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 4),
          ObservationSelector(analysis: analysis),
          const SizedBox(height: 12),
          TileWrap(
            minTileWidth: 140,
            children: <Widget>[
              MetricTile(
                label: 'Strongest LOS displacement',
                value: formatMm(d.maxLosDisplacementMm),
                caption: 'Cumulative, over full period',
              ),
              MetricTile(
                label: 'Median across zones',
                value: formatMm(d.medianLosDisplacementMm),
              ),
              MetricTile(
                label: 'Monitored area',
                value: formatKm2(d.monitoredAreaKm2),
                caption: d.zoneCount == null ? null : '${d.zoneCount} zones',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(d.losConvention,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          if (d.noiseNote != null) ...<Widget>[
            const SizedBox(height: 8),
            Tag(label: d.noiseNote!, color: AppColors.warning, icon: Icons.graphic_eq),
          ],
          const SizedBox(height: 16),
          Text('Cumulative displacement over time',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DeformationChart(analysis: analysis, selection: sel),
          const SizedBox(height: 10),
          Text(
            'Measured ground motion along the satellite line of sight. It is '
            'monitoring evidence, not a landslide prediction.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Model-based estimate. Always visually distinct from observations.
class PredictionSection extends StatelessWidget {
  const PredictionSection({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = analysis.prediction;
    final isFlood = analysis.hazard == HazardType.floodExpansion;
    final title =
        isFlood ? 'Future flood expansion estimate' : 'Landslide susceptibility';
    final Widget body;
    if (!p.status.hasResult) {
      body = UnavailablePanel(
        key: const Key('prediction-unavailable'),
        icon: Icons.auto_graph,
        title: 'Not available',
        message: '${p.description ?? 'No model estimate has been produced.'} '
            '${isFlood ? 'The observed change above must not be extrapolated into a forecast.' : 'Measured deformation above is not a landslide prediction.'}',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              Tag(label: p.kind.label, color: AppColors.predicted),
              if (!p.isCalibrated)
                const Tag(label: 'Uncalibrated', color: AppColors.warning),
            ],
          ),
          if (p.label != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(p.label!, style: theme.textTheme.titleSmall),
          ],
          if (p.forecastHorizon != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Horizon: ${p.forecastHorizon}', style: theme.textTheme.bodyMedium),
          ],
          if (p.description != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(p.description!, style: theme.textTheme.bodyMedium),
          ],
          if (p.caveats.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text('Read with care', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            BulletList(p.caveats),
          ],
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.explore),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('View layer in Explore'),
          ),
        ],
      );
    }
    return SectionCard(
      title: title,
      accent: AppColors.predicted,
      trailing: StatusChip(p.status),
      child: body,
    );
  }
}

/// Held-out validation, or an explicit "not evaluated".
class ValidationSection extends ConsumerWidget {
  const ValidationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final value = ref.watch(currentValidationProvider);
    return SectionCard(
      title: 'Model validation',
      child: AsyncValueView<ValidationResult?>(
        value: value,
        loadingLabel: 'Loading validation...',
        onRetry: () => ref.invalidate(currentValidationProvider),
        data: (ValidationResult? v) {
          if (v == null) {
            return const UnavailablePanel(
              compact: true,
              title: 'No validation record',
              message: 'Nothing has been validated for this analysis.',
            );
          }
          if (!v.status.hasResult) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                StatusChip(v.status),
                const SizedBox(height: 10),
                Text(
                  'This analysis has not been tested against independent '
                  'data, so its accuracy is unknown. "Not evaluated" is not '
                  'a pass.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (v.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  BulletList(v.notes),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                StatusChip(v.status),
                if (v.isSample) const SampleDataBadge(),
              ]),
              const SizedBox(height: 10),
              if (v.method != null) Text('Method: ${v.method}', style: theme.textTheme.bodyMedium),
              if (v.testPeriod != null)
                Text('Test data: ${v.testPeriod}', style: theme.textTheme.bodyMedium),
              if (v.splitStrategy != null)
                Text('Split: ${v.splitStrategy}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              if (v.metrics.isNotEmpty)
                TileWrap(
                  minTileWidth: 130,
                  children: <Widget>[
                    for (final m in v.metrics)
                      MetricTile(
                        label: m.name,
                        value: formatMeasure(m.value,
                            decimals: 2, unit: m.unit ?? ''),
                        caption: m.description,
                      ),
                  ],
                ),
              if (v.notes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                BulletList(v.notes),
              ],
              if (v.limitations.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                BulletList(v.limitations, icon: Icons.report_gmailerrorred_outlined),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Data quality flags, limitations and sources.
class QualitySection extends StatelessWidget {
  const QualitySection({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Data quality and uncertainty',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (analysis.qualityFlags.isEmpty)
            Text('No quality flags were recorded.',
                style: theme.textTheme.bodyMedium)
          else
            for (final f in analysis.qualityFlags)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      f.level == QualityLevel.warning
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      size: 20,
                      color: f.level == QualityLevel.warning
                          ? AppColors.warning
                          : AppColors.info,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(f.label, style: theme.textTheme.titleSmall),
                          Text(f.detail,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (analysis.limitations.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('Known limitations', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            BulletList(analysis.limitations),
          ],
          if (analysis.dataSources.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text('Data sources', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            BulletList([
              for (final s in analysis.dataSources)
                s.note == null ? s.label : '${s.label} - ${s.note}',
            ]),
          ],
          if (analysis.processingVersion != null || analysis.crs != null)
            Text(
              [
                if (analysis.processingVersion != null)
                  'Processing: ${analysis.processingVersion}',
                if (analysis.crs != null) 'CRS: ${analysis.crs}',
              ].join('  |  '),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// "Why this area?" - zone evidence plus ranked contributing factors.
class WhyHighlightedSection extends ConsumerWidget {
  const WhyHighlightedSection({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectionProvider.select((s) => s.zoneId));
    final zone = effectiveZone(analysis, selectedId);
    final explanation = ref.watch(currentExplanationProvider);

    if (zone == null) {
      return const SectionCard(
        title: 'Why this area?',
        child: UnavailablePanel(
          compact: true,
          title: 'No zones highlighted',
          message: 'The analysis record lists no priority zones.',
        ),
      );
    }
    return SectionCard(
      title: 'Why this area?',
      subtitle: 'Evidence, contributing factors and limits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final z in analysis.zonesByRank)
                ChoiceChip(
                  key: Key('why-chip-${z.id}'),
                  label: Text('${z.rank}  ${_short(z.name)}'),
                  selected: z.id == zone.id,
                  onSelected: (bool on) => ref
                      .read(selectionProvider.notifier)
                      .selectZone(z.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
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
                if (zone.evidence.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text('Evidence', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  BulletList(zone.evidence),
                ],
                if (zone.dataQuality != null)
                  Text('Data quality: ${zone.dataQuality}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Contributing factors (model inputs)',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          AsyncValueView<ExplanationResult?>(
            value: explanation,
            loadingLabel: 'Loading explanation...',
            onRetry: () => ref.invalidate(currentExplanationProvider),
            data: (ExplanationResult? e) {
              if (e == null || !e.status.hasResult || e.factors.isEmpty) {
                return UnavailablePanel(
                  key: const Key('explanation-unavailable'),
                  compact: true,
                  title: 'No model explanation',
                  message: e?.caveat ??
                      'No explanation is available for this analysis.',
                );
              }
              final factors = List<ContributingFactor>.of(e.factors)
                ..sort((a, b) => a.rank.compareTo(b.rank));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (e.method != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Method: ${e.method}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
                    ),
                  for (final f in factors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.navy600,
                            child: Text('${f.rank}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(f.name, style: theme.textTheme.titleSmall),
                                Text(
                                  '${f.description}'
                                  '${_direction(f.direction)}'
                                  '${f.importance == null ? '' : ' (importance ${f.importance!.toStringAsFixed(2)})'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (e.caveat != null)
                    Text(e.caveat!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.warning)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _direction(String? d) {
    switch (d) {
      case 'increases':
        return ' Raises the estimate.';
      case 'decreases':
        return ' Lowers the estimate as it increases.';
      case 'context':
        return ' Context only.';
      default:
        return '';
    }
  }

  String _short(String name) {
    final i = name.indexOf(' - ');
    return i > 0 ? name.substring(0, i) : name;
  }
}
