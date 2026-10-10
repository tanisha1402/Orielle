import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_extensions.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/hazard_zone.dart';
import '../../models/impact_summary.dart';
import '../../state/providers.dart';

/// Formats an exposure amount, e.g. `~ 1,200 buildings`.
String formatExposure(ExposureCount? e, AssetCategory category) {
  if (e == null || e.value == null) return 'Not available';
  final approx = e.approximate ? '\u2248 ' : '';
  final decimals = category == AssetCategory.roads ? 1 : 0;
  return '$approx${formatThousands(e.value!, decimals: decimals)}';
}

/// Exposure summary for the selected zone.
class ImpactContent extends ConsumerStatefulWidget {
  const ImpactContent({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  ConsumerState<ImpactContent> createState() => _ImpactContentState();
}

class _ImpactContentState extends ConsumerState<ImpactContent> {
  final Set<AssetCategory> _visible = AssetCategory.values.toSet();
  AssetCategory _chartCategory = AssetCategory.buildings;

  @override
  Widget build(BuildContext context) {
    final impact = ref.watch(currentImpactProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AsyncValueView<ImpactSummary?>(
        value: impact,
        loadingLabel: 'Loading exposure summary...',
        onRetry: () => ref.invalidate(currentImpactProvider),
        data: (ImpactSummary? summary) {
          if (summary == null ||
              !summary.status.hasResult ||
              summary.zoneImpacts.isEmpty) {
            return const UnavailablePanel(
              title: 'No exposure summary',
              message: 'No exposure data is available for this analysis. '
                  'That does not mean nothing is exposed.',
            );
          }
          return _build(context, summary);
        },
      ),
    );
  }

  Widget _build(BuildContext context, ImpactSummary summary) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectionProvider.select((s) => s.zoneId));
    final zoneImpact =
        summary.impactForZone(selectedId) ?? summary.zoneImpacts.first;
    final categories = AssetCategory.values
        .where((c) => _visible.contains(c))
        .toList(growable: false);
    final chartCat =
        categories.contains(_chartCategory) || categories.isEmpty
            ? _chartCategory
            : categories.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (summary.isSample) ...<Widget>[
          const SampleDataBanner(
            message: 'SAMPLE DATA: all exposure figures are illustrative '
                'and rounded. They are not an infrastructure inventory.',
          ),
          const SizedBox(height: 12),
        ],
        _DisclaimerCard(text: summary.disclaimer),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Hazard zone',
          subtitle: 'Choose the zone to inspect',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final z in summary.zoneImpacts)
                    ChoiceChip(
                      key: Key('impact-zone-${z.zoneId}'),
                      label: Text(_short(z.zoneName)),
                      selected: z.zoneId == zoneImpact.zoneId,
                      onSelected: (_) => ref
                          .read(selectionProvider.notifier)
                          .selectZone(z.zoneId),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  BasisChip(zoneImpact.basis),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      zoneImpact.basis == ZoneBasis.observed
                          ? 'Observed affected area: assets that intersect '
                              'a zone mapped from observations.'
                          : 'Estimated future-risk zone (preliminary): '
                              'exposure here is hypothetical, not observed.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(zoneImpact.zoneName, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Potentially exposed assets',
          subtitle: 'Filter categories',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final c in AssetCategory.values)
                    FilterChip(
                      key: Key('filter-${c.apiValue}'),
                      label: Text(c.label),
                      selected: _visible.contains(c),
                      onSelected: (bool on) => setState(() {
                        if (on) {
                          _visible.add(c);
                        } else {
                          _visible.remove(c);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                const UnavailablePanel(
                  compact: true,
                  title: 'No category selected',
                  message: 'Select at least one asset category above.',
                )
              else
                TileWrap(
                  minTileWidth: 150,
                  children: <Widget>[
                    for (final c in categories)
                      _ExposureCard(
                        category: c,
                        exposure: zoneImpact.exposureFor(c),
                        maxAcrossZones: _maxFor(summary, c),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isNotEmpty)
          SectionCard(
            title: 'Compare zones',
            subtitle: '${chartCat.label} per zone (${chartCat.unit})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final c in categories)
                      ChoiceChip(
                        key: Key('chart-${c.apiValue}'),
                        label: Text(c.label),
                        selected: c == chartCat,
                        onSelected: (_) => setState(() => _chartCategory = c),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _ZoneComparisonChart(
                  summary: summary,
                  category: chartCat,
                  selectedZoneId: zoneImpact.zoneId,
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Data sources, dates and coverage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final c in categories)
                if (summary.noteFor(c) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text.rich(TextSpan(children: <InlineSpan>[
                      TextSpan(
                          text: '${c.label}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                        text: '${summary.noteFor(c)!.source}'
                            '${summary.noteFor(c)!.dataDate == null ? '' : ', ${summary.noteFor(c)!.dataDate}'}'
                            '. ${summary.noteFor(c)!.coverage}',
                      ),
                    ]), style: theme.textTheme.bodyMedium),
                  ),
              if (categories.isEmpty || categories.every((c) => summary.noteFor(c) == null))
                Text('No source notes recorded for the selected categories.',
                    style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  double? _maxFor(ImpactSummary summary, AssetCategory c) {
    double? max;
    for (final z in summary.zoneImpacts) {
      final v = z.exposureFor(c)?.value;
      if (v != null && (max == null || v > max)) max = v;
    }
    return max;
  }

  String _short(String name) {
    final i = name.indexOf(' - ');
    return i > 0 ? name.substring(0, i) : name;
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: withFraction(AppColors.info, 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: withFraction(AppColors.info, 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Potentially exposed is not damaged. $text',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExposureCard extends StatelessWidget {
  const _ExposureCard({
    required this.category,
    required this.exposure,
    required this.maxAcrossZones,
  });

  final AssetCategory category;
  final ExposureCount? exposure;
  final double? maxAcrossZones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = exposure?.value;
    final available = value != null;
    final fraction = (available && maxAcrossZones != null && maxAcrossZones! > 0)
        ? (value! / maxAcrossZones!).clamp(0.0, 1.0).toDouble()
        : null;
    return Container(
      key: Key('impact-card-${category.apiValue}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.navy600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(category.label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            formatExposure(exposure, category),
            style: TextStyle(
              fontSize: available ? 22 : 15,
              fontWeight: FontWeight.w700,
              color: available ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          if (available)
            Text(category.unit,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          if (fraction != null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.navy600,
                color: AppColors.teal400,
              ),
            ),
            const SizedBox(height: 4),
            Text('relative to the largest zone',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.textMuted)),
          ],
          if (exposure?.note != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(exposure!.note!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
          if (exposure?.isIllustrative ?? false) ...<Widget>[
            const SizedBox(height: 8),
            const Tag(label: 'Illustrative', color: AppColors.warning),
          ],
        ],
      ),
    );
  }
}

class _ZoneComparisonChart extends StatelessWidget {
  const _ZoneComparisonChart({
    required this.summary,
    required this.category,
    required this.selectedZoneId,
  });

  final ImpactSummary summary;
  final AssetCategory category;
  final String selectedZoneId;

  @override
  Widget build(BuildContext context) {
    final zones = summary.zoneImpacts;
    var maxValue = 0.0;
    for (final z in zones) {
      final v = z.exposureFor(category)?.value;
      if (v != null && v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) {
      return const Text('No values are available for this category.');
    }
    const axis = TextStyle(color: AppColors.textSecondary, fontSize: 11);
    final description = [
      for (final z in zones)
        '${z.zoneName}: ${formatExposure(z.exposureFor(category), category)}',
    ].join('; ');
    return Semantics(
      label: 'Bar chart of ${category.label} per zone. $description',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.2,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (double v) =>
                      FlLine(color: AppColors.navy600, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (double v, TitleMeta m) =>
                          Text(formatThousands(v), style: axis),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (double v, TitleMeta m) {
                        final i = v.round();
                        if ((v - i).abs() > 0.01 || i < 0 || i >= zones.length) {
                          return const SizedBox.shrink();
                        }
                        final name = zones[i].zoneName;
                        final cut = name.indexOf(' - ');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(cut > 0 ? name.substring(0, cut) : name,
                              style: axis),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (var i = 0; i < zones.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: zones[i].exposureFor(category)?.value ?? 0,
                          width: 28,
                          color: zones[i].zoneId == selectedZoneId
                              ? zones[i].basis.color
                              : withFraction(zones[i].basis.color, 0.45),
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (BarChartGroupData g, int gi,
                        BarChartRodData rod, int ri) {
                      return BarTooltipItem(
                        '${zones[g.x].zoneName}\n'
                        '${formatExposure(zones[g.x].exposureFor(category), category)} ${category.unit}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bright bar = selected zone. Blue = observed zone, violet = '
            'estimated zone. A zone with no data is drawn as zero and listed as '
            '"Not available" in its card.',
            style: axis,
          ),
        ],
      ),
    );
  }
}
