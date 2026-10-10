import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_extensions.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/study_area.dart';
import '../../state/providers.dart';
import '../common/area_picker.dart';
import '../common/data_origin_badge.dart';

/// Screen 1 - Home / Earth Today.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.public, color: AppColors.teal400),
            const SizedBox(width: 8),
            Flexible(
              child: Text(AppConfig.appName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(letterSpacing: 1.2, fontSize: 17)),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'About this data',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push(AppRoutes.about),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const <Widget>[
            _HeroHeader(),
            SizedBox(height: 16),
            _HazardCards(),
            SizedBox(height: 16),
            _SurfaceChangeCard(),
            SizedBox(height: 16),
            _PriorityAreasCard(),
            SizedBox(height: 16),
            _DataAvailabilityCard(),
            SizedBox(height: 8),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.navy700, AppColors.teal700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy500),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Earth Today', style: theme.textTheme.displaySmall),
              ),
              const DataOriginBadge(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Satellite-observed surface change, the hazard evidence that '
            'supports it, and what may be exposed.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('SELECTED REGION',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerLeft, child: AreaPickerButton()),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('open-explore'),
            onPressed: () => context.go(AppRoutes.explore),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Explore'),
          ),
        ],
      ),
    );
  }
}

class _HazardCards extends StatelessWidget {
  const _HazardCards();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const flood = HazardSummaryCard(hazard: HazardType.floodExpansion);
        const slope = HazardSummaryCard(hazard: HazardType.slopeDeformation);
        if (c.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Expanded(child: flood),
              SizedBox(width: 12),
              Expanded(child: slope),
            ],
          );
        }
        return Column(
          children: const <Widget>[flood, SizedBox(height: 12), slope],
        );
      },
    );
  }
}

/// Summary card for one hazard in the selected region.
class HazardSummaryCard extends ConsumerWidget {
  const HazardSummaryCard({super.key, required this.hazard});

  final HazardType hazard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryForHazardProvider(hazard));
    final area = ref.watch(effectiveAreaProvider).valueOrNull;
    final theme = Theme.of(context);
    return summary.when(
      loading: () => SectionCard(
        title: hazard.label,
        child: const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
        ),
      ),
      error: (Object e, StackTrace s) => SectionCard(
        title: hazard.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Could not load this summary.',
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () => ref.invalidate(analysisSummariesProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (AnalysisSummary? s) {
        if (s == null) {
          return SectionCard(
            title: hazard.label,
            accent: hazard.color,
            child: UnavailablePanel(
              compact: true,
              title: 'No analysis for this region',
              message: '${area?.name ?? 'This region'} has no '
                  '${hazard.label.toLowerCase()} analysis.',
              actionLabel: 'Show a region with this hazard',
              onAction: () {
                final areas = ref.read(areasProvider).valueOrNull ??
                    const <StudyArea>[];
                ref.read(selectionProvider.notifier).selectHazard(hazard, areas);
              },
            ),
          );
        }
        final hasValue = s.headlineValue != null;
        return SectionCard(
          accent: hazard.color,
          title: hazard.label,
          trailing: StatusChip(s.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(hazard.icon, color: hazard.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.latestObservationDate == null
                          ? 'Latest observation: not available'
                          : 'Latest observation: ${formatDate(s.latestObservationDate!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MetricTile(
                label: s.headlineLabel ?? 'Observed change',
                value: hasValue
                    ? formatMeasure(s.headlineValue,
                        unit: s.headlineUnit ?? '',
                        // A '+' only makes sense for a change, not an extent.
                        signed: (s.headlineLabel ?? '')
                            .toLowerCase()
                            .contains('change'))
                    : 'Not available',
                caption: hasValue
                    ? 'Observed only - not a forecast. ${s.observationCount} observations.'
                    : 'No measurement yet.',
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (s.isSample) const Flexible(child: SampleDataBadge()),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      final areas = ref.read(areasProvider).valueOrNull ??
                          const <StudyArea>[];
                      ref
                          .read(selectionProvider.notifier)
                          .selectHazard(hazard, areas);
                      context.go(AppRoutes.explore);
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Explore'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Analyses of the selected region for both hazards (null when absent).
List<AnalysisResult> _analyses(WidgetRef ref) {
  final out = <AnalysisResult>[];
  for (final h in HazardType.values) {
    final a = ref.watch(analysisForHazardProvider(h)).valueOrNull;
    if (a != null) out.add(a);
  }
  return out;
}

class _SurfaceChangeCard extends ConsumerWidget {
  const _SurfaceChangeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lines = <Widget>[];
    for (final a in _analyses(ref)) {
      if (!a.status.hasResult) continue;
      final first = a.firstObservation;
      final last = a.latestObservation;
      if (first == null || last == null) continue;
      final period = '${formatDate(first.date)} \u2192 ${formatDate(last.date)}';
      String text;
      if (a.hazard == HazardType.floodExpansion) {
        final stat = a.changeFor(first.id, last.id);
        text = stat?.netChangeKm2 == null
            ? 'Flood extent: change statistics not available.'
            : 'Flood extent: net ${formatKm2(stat!.netChangeKm2, signed: true)} '
                '($period).';
      } else {
        final mm = a.deformation?.maxLosDisplacementMm;
        text = mm == null
            ? 'Slope deformation: no displacement measurement available.'
            : 'Slope deformation: strongest cumulative line-of-sight '
                'displacement ${formatMm(mm)} ($period). Measured movement, '
                'not a landslide prediction.';
      }
      lines.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(a.hazard.icon, size: 18, color: a.hazard.color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ));
    }
    return SectionCard(
      title: 'Observed surface change',
      subtitle: 'What changed between satellite observation dates',
      child: lines.isEmpty
          ? const UnavailablePanel(
              compact: true,
              title: 'Nothing to summarise',
              message: 'No observed change is available for this region. '
                  'That is not evidence that nothing changed.',
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
    );
  }
}

class _PriorityAreasCard extends ConsumerWidget {
  const _PriorityAreasCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final zones = <HazardZone>[];
    for (final a in _analyses(ref)) {
      if (a.status.hasResult) zones.addAll(a.zonesByRank);
    }
    zones.sort((a, b) => a.rank.compareTo(b.rank));
    final shown = zones.take(5).toList();
    return SectionCard(
      title: 'Priority areas',
      subtitle: 'Listed only where supported by analysis results',
      child: shown.isEmpty
          ? const UnavailablePanel(
              compact: true,
              title: 'No priority areas',
              message: 'No zones are supported by results for this region.',
            )
          : Column(
              children: <Widget>[
                for (final z in shown)
                  InkWell(
                    key: Key('priority-${z.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(selectionProvider.notifier).focusZone(z.hazard, z.id);
                      context.go(AppRoutes.explore);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: z.basis.color,
                            child: Text('${z.rank}',
                                style: const TextStyle(
                                    color: AppColors.navy950,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(z.name, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: <Widget>[
                                    Text(z.hazard.shortLabel,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary)),
                                    BasisChip(z.basis),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(z.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DataAvailabilityCard extends ConsumerWidget {
  const _DataAvailabilityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final h in HazardType.values) {
      final value = ref.watch(analysisForHazardProvider(h));
      final a = value.valueOrNull;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              Icon(h.icon, size: 18, color: h.color),
              const SizedBox(width: 8),
              Text(h.label, style: theme.textTheme.titleSmall),
            ]),
            const SizedBox(height: 6),
            if (value.isLoading)
              Text('Loading...', style: theme.textTheme.bodySmall)
            else if (a == null)
              Text('No analysis for this region.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  StatusChip(a.status, prefix: 'Analysis'),
                  StatusChip(a.prediction.status, prefix: 'Prediction'),
                  StatusChip(a.validationStatus, prefix: 'Validation'),
                  Text('${a.observations.length} observations',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
          ],
        ),
      ));
    }
    return SectionCard(
      title: 'Data availability and status',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(effectiveAreaProvider).valueOrNull;
    final isReal = area != null && !area.isSample;
    return Column(
      children: <Widget>[
        SampleDataBanner(
          message: isReal
              ? 'REAL HISTORICAL DATA: published records for the August 2024 '
                  'floods (sources under Data quality). Figures marked '
                  'preliminary are not validated. Nothing here is live.'
              : null,
        ),
        TextButton.icon(
          onPressed: () => context.push(AppRoutes.about),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('About this sample data'),
        ),
      ],
    );
  }
}
