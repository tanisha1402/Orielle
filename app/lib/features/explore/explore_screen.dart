import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/panels.dart';
import '../../state/providers.dart';
import '../common/analysis_gate.dart';
import '../common/data_origin_badge.dart';
import '../common/scope_bar.dart';
import 'explore_map.dart';
import 'explore_panels.dart';

/// Screen 2 - Explore the Earth.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(exploreDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DataOriginBadge()),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const ScopeBar(padding: EdgeInsets.fromLTRB(16, 4, 16, 8)),
          Expanded(
            child: data.when(
              loading: () => const LoadingPanel(label: 'Loading map data...'),
              error: (Object e, StackTrace s) => ErrorPanel(
                error: e,
                onRetry: () {
                  ref.invalidate(analysisSummariesProvider);
                  ref.invalidate(areasProvider);
                },
              ),
              data: (ExploreData? d) {
                if (d == null) {
                  // No analysis for this area + hazard: reuse the shared gate
                  // so the message and the recovery action stay consistent.
                  return ListView(
                    padding: const EdgeInsets.only(top: 8),
                    children: <Widget>[AnalysisGate(builder: (a) => const SizedBox())],
                  );
                }
                return _ExploreBody(data: d);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreBody extends StatelessWidget {
  const _ExploreBody({required this.data});

  final ExploreData data;

  @override
  Widget build(BuildContext context) {
    final mapKey = ValueKey<String>('map-${data.analysis.id}');
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final map = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ExploreMap(key: mapKey, data: data),
        );
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
                  child: map,
                ),
              ),
              SizedBox(width: 400, child: ExplorePanels(data: data)),
            ],
          );
        }
        final mapHeight = (c.maxHeight * 0.46).clamp(230.0, 460.0).toDouble();
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SizedBox(height: mapHeight, child: map),
            ),
            Expanded(child: ExplorePanels(data: data)),
          ],
        );
      },
    );
  }
}
