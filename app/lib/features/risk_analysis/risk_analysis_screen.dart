import 'package:flutter/material.dart';

import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/hazard_type.dart';
import '../common/analysis_gate.dart';
import '../common/data_origin_badge.dart';
import '../common/scope_bar.dart';
import 'risk_sections.dart';

/// Screen 3 - Risk Analysis.
class RiskAnalysisScreen extends StatelessWidget {
  const RiskAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Analysis'),
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
            AnalysisGate(builder: (AnalysisResult a) => _RiskBody(analysis: a)),
          ],
        ),
      ),
    );
  }
}

class _RiskBody extends StatelessWidget {
  const _RiskBody({required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final isFlood = analysis.hazard == HazardType.floodExpansion;
    const gap = SizedBox(height: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RiskHeader(analysis: analysis),
          gap,
          if (isFlood)
            FloodChangeSection(analysis: analysis)
          else
            DeformationSection(analysis: analysis),
          gap,
          PredictionSection(analysis: analysis),
          gap,
          const ValidationSection(),
          gap,
          QualitySection(analysis: analysis),
          gap,
          WhyHighlightedSection(analysis: analysis),
        ],
      ),
    );
  }
}
