import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/analysis_result.dart';
import '../../models/hazard_type.dart';
import '../../state/providers.dart';

/// Observation timeline control shared by Explore and Risk Analysis.
///
/// Flood: a range slider picks the "before" and "after" observation.
/// Slope: a single slider picks the "as of" observation.
class ObservationSelector extends ConsumerWidget {
  const ObservationSelector({super.key, required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = analysis.observations;
    final sel = ref.watch(observationSelectionProvider);
    if (obs.isEmpty || sel == null) {
      return const Text('No observation dates are available.');
    }
    if (obs.length < 2) {
      return Text('Single observation: ${formatDate(obs.first.date)}.');
    }
    final maxIndex = (obs.length - 1).toDouble();
    final notifier = ref.read(observationOverrideProvider(analysis.id).notifier);
    final isFlood = analysis.hazard == HazardType.floodExpansion;

    final Widget slider;
    if (isFlood) {
      slider = RangeSlider(
        key: const Key('observation-range'),
        values: RangeValues(sel.beforeIndex.toDouble(), sel.afterIndex.toDouble()),
        min: 0,
        max: maxIndex,
        divisions: obs.length - 1,
        labels: RangeLabels(
          formatDateShort(obs[sel.beforeIndex].date),
          formatDateShort(obs[sel.afterIndex].date),
        ),
        onChanged: (RangeValues v) {
          notifier.state = ObservationSelection(
            beforeIndex: v.start.round(),
            afterIndex: v.end.round(),
          );
        },
      );
    } else {
      slider = Slider(
        key: const Key('observation-single'),
        value: sel.afterIndex.toDouble(),
        min: 0,
        max: maxIndex,
        divisions: obs.length - 1,
        label: formatDate(obs[sel.afterIndex].date),
        onChanged: (double v) {
          notifier.state =
              ObservationSelection(beforeIndex: 0, afterIndex: v.round());
        },
      );
    }

    final showAll = obs.length <= 7;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: showAll
              ? Row(
                  children: <Widget>[
                    for (final o in obs)
                      Expanded(
                        child: Text(
                          formatDateShort(o.date),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(formatDateShort(obs.first.date), style: labelStyle),
                    Text(formatDateShort(obs.last.date), style: labelStyle),
                  ],
                ),
        ),
      ],
    );
  }
}
