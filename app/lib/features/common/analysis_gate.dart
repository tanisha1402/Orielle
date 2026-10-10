import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/data_status.dart';
import '../../models/study_area.dart';
import '../../state/providers.dart';

/// Resolves the current analysis and handles loading, error, "no analysis for
/// this area/hazard", "not available" and "error" states, so screens only
/// render the happy path in [builder].
class AnalysisGate extends ConsumerWidget {
  const AnalysisGate({super.key, required this.builder});

  final Widget Function(AnalysisResult analysis) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(currentAnalysisProvider);
    return value.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingPanel(label: 'Loading analysis...'),
      ),
      error: (Object e, StackTrace s) => ErrorPanel(
        error: e,
        onRetry: () {
          ref.invalidate(analysisSummariesProvider);
          ref.invalidate(areasProvider);
        },
      ),
      data: (AnalysisResult? analysis) {
        if (analysis == null) return const _NoAnalysis();
        if (analysis.status == DataStatus.notAvailable) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UnavailablePanel(
              title: 'No analysis data yet',
              message: analysis.statusNote ??
                  'This analysis has no usable results. Missing data must '
                      'not be read as "no hazard".',
            ),
          );
        }
        if (analysis.status == DataStatus.error) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UnavailablePanel(
              icon: Icons.error_outline,
              title: 'This analysis reported an error',
              message: analysis.statusNote ??
                  'The processing pipeline flagged this analysis as failed.',
            ),
          );
        }
        return builder(analysis);
      },
    );
  }
}

class _NoAnalysis extends ConsumerWidget {
  const _NoAnalysis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazard = ref.watch(currentHazardProvider);
    final area = ref.watch(effectiveAreaProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: UnavailablePanel(
        title: 'No ${hazard.label.toLowerCase()} analysis here',
        message: '${area?.name ?? 'This region'} has no ${hazard.label.toLowerCase()} '
            'analysis. Pick another region or switch hazard.',
        actionLabel: 'Show a region with this hazard',
        onAction: () {
          final areas = ref.read(areasProvider).valueOrNull ?? const <StudyArea>[];
          ref.read(selectionProvider.notifier).selectHazard(hazard, areas);
        },
      ),
    );
  }
}
