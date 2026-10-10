import 'package:flutter/material.dart';

import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../common/analysis_gate.dart';
import '../common/data_origin_badge.dart';
import '../common/scope_bar.dart';
import 'impact_content.dart';

/// Screen 4 - Impact.
class ImpactScreen extends StatelessWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impact'),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DataOriginBadge()),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            const ScopeBar(),
            AnalysisGate(
              builder: (AnalysisResult a) => ImpactContent(analysis: a),
            ),
          ],
        ),
      ),
    );
  }
}
