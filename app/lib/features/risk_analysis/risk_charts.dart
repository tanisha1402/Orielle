import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/analysis_result.dart';
import '../../models/hazard_zone.dart';
import '../../state/providers.dart';

const TextStyle _axisStyle = TextStyle(color: AppColors.textSecondary, fontSize: 11);

FlTitlesData _titles(AnalysisResult analysis, {double leftReserved = 44}) {
  final obs = analysis.observations;
  return FlTitlesData(
    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: leftReserved,
        getTitlesWidget: (double value, TitleMeta meta) =>
            Text(value.toStringAsFixed(0), style: _axisStyle),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          final i = value.round();
          if ((value - i).abs() > 0.01 || i < 0 || i >= obs.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(formatDateShort(obs[i].date), style: _axisStyle),
          );
        },
      ),
    ),
  );
}

FlGridData _grid() => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (double v) =>
          FlLine(color: AppColors.navy600, strokeWidth: 1),
    );

/// Mapped flood extent per observation. Before/after dates are highlighted.
class FloodExtentChart extends StatelessWidget {
  const FloodExtentChart({
    super.key,
    required this.analysis,
    required this.selection,
  });

  final AnalysisResult analysis;
  final ObservationSelection? selection;

  @override
  Widget build(BuildContext context) {
    final obs = analysis.observations;
    var maxValue = 0.0;
    for (final o in obs) {
      final v = o.floodExtentKm2;
      if (v != null && v > maxValue) maxValue = v;
    }
    if (maxValue <= 0) {
      return const Text('No per-observation flood extent values are available.');
    }
    final groups = <BarChartGroupData>[
      for (var i = 0; i < obs.length; i++)
        BarChartGroupData(
          x: i,
          barRods: <BarChartRodData>[
            BarChartRodData(
              toY: obs[i].floodExtentKm2 ?? 0,
              width: 26,
              color: _barColor(i),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ],
        ),
    ];
    final summary = [
      for (final o in obs)
        '${formatDateShort(o.date)}: ${formatKm2(o.floodExtentKm2)}',
    ].join(', ');
    return Semantics(
      label: 'Bar chart of mapped flood extent per observation. $summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.2,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: _grid(),
                borderData: FlBorderData(show: false),
                titlesData: _titles(analysis),
                barGroups: groups,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (BarChartGroupData group, int groupIndex,
                        BarChartRodData rod, int rodIndex) {
                      return BarTooltipItem(
                        '${formatDate(obs[group.x].date)}\n${formatKm2(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: const <Widget>[
              _Dot(color: AppColors.teal400),
              SizedBox(width: 4),
              Text('Before date', style: _axisStyle),
              SizedBox(width: 12),
              _Dot(color: AppColors.flood),
              SizedBox(width: 4),
              Text('After date', style: _axisStyle),
              SizedBox(width: 12),
              _Dot(color: AppColors.navy500),
              SizedBox(width: 4),
              Text('Other', style: _axisStyle),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: _axisStyle),
        ],
      ),
    );
  }

  Color _barColor(int i) {
    final s = selection;
    if (s != null) {
      if (i == s.afterIndex && i != s.beforeIndex) return AppColors.flood;
      if (i == s.beforeIndex) return AppColors.teal400;
    }
    return AppColors.navy500;
  }
}

/// Cumulative line-of-sight displacement over time: mean + observed zones.
class DeformationChart extends StatelessWidget {
  const DeformationChart({
    super.key,
    required this.analysis,
    required this.selection,
  });

  final AnalysisResult analysis;
  final ObservationSelection? selection;

  @override
  Widget build(BuildContext context) {
    final obs = analysis.observations;
    final mean = <FlSpot>[
      for (var i = 0; i < obs.length; i++)
        if (obs[i].meanLosDisplacementMm != null)
          FlSpot(i.toDouble(), obs[i].meanLosDisplacementMm!),
    ];
    if (mean.length < 2) {
      return const Text('Not enough displacement values to draw a trend.');
    }
    final zoneColors = <Color>[AppColors.danger, AppColors.warning, AppColors.textSecondary];
    final lines = <LineChartBarData>[];
    final legend = <Widget>[];
    var zoneIndex = 0;
    var minY = 0.0;
    var maxY = 0.0;
    for (final s in mean) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    for (final HazardZone z in analysis.zonesByRank) {
      if (z.valuesByObservation.isEmpty) continue;
      final spots = <FlSpot>[
        for (var i = 0; i < obs.length; i++)
          if (z.valuesByObservation[obs[i].id] != null)
            FlSpot(i.toDouble(), z.valuesByObservation[obs[i].id]!),
      ];
      if (spots.length < 2) continue;
      for (final s in spots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
      final color = zoneColors[zoneIndex % zoneColors.length];
      zoneIndex++;
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: 1.5,
        dotData: FlDotData(show: false),
      ));
      legend.addAll(<Widget>[
        _Dot(color: color),
        const SizedBox(width: 4),
        Text(_short(z.name), style: _axisStyle),
        const SizedBox(width: 12),
      ]);
    }
    final selected = selection?.afterIndex ?? obs.length - 1;
    lines.add(LineChartBarData(
      spots: mean,
      isCurved: false,
      color: AppColors.slope,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (FlSpot spot, double percent, LineChartBarData bar, int index) {
          final isSelected = spot.x.round() == selected;
          return FlDotCirclePainter(
            radius: isSelected ? 6 : 3.5,
            color: isSelected ? Colors.white : AppColors.slope,
            strokeWidth: 0,
          );
        },
      ),
    ));
    legend.addAll(const <Widget>[
      _Dot(color: AppColors.slope),
      SizedBox(width: 4),
      Text('Mean of zones', style: _axisStyle),
    ]);

    final summary = [
      for (final o in obs)
        '${formatDateShort(o.date)}: ${formatMm(o.meanLosDisplacementMm)}',
    ].join(', ');
    return Semantics(
      label: 'Line chart of cumulative line-of-sight displacement in millimetres. $summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY - 3,
                maxY: maxY + 2,
                gridData: _grid(),
                borderData: FlBorderData(show: false),
                titlesData: _titles(analysis),
                lineBarsData: lines,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> spots) => <LineTooltipItem?>[
                      for (final s in spots)
                        LineTooltipItem(
                          '${formatDateShort(obs[s.x.round()].date)}: ${s.y.toStringAsFixed(1)} mm',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: legend),
          const SizedBox(height: 6),
          Text(
            'Highlighted point = selected "as of" date. Values in mm, line of sight.',
            style: _axisStyle,
          ),
        ],
      ),
    );
  }

  String _short(String name) {
    final i = name.indexOf(' - ');
    return i > 0 ? name.substring(0, i) : name;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
