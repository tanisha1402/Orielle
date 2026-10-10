import '../../core/utils/formatters.dart';
import '../../models/analysis_result.dart';
import '../../models/chat_message.dart';
import '../../models/data_status.dart';
import '../../models/hazard_type.dart';
import '../../models/hazard_zone.dart';
import '../../models/impact_summary.dart';
import 'mock_data.dart';

typedef BundleLookup = MockBundle? Function(String analysisId);

/// Keyword-based demo "assistant" that answers from the local SAMPLE records.
///
/// This is NOT an AI model. It matches a handful of intents and composes
/// answers from stored fields; when a field is missing it says so. It never
/// infers safety from missing data.
class MockAskEngine {
  const MockAskEngine({this.lookup = MockData.bundleFor});

  final BundleLookup lookup;

  static const String _sampleNote =
      'These figures come from the SAMPLE dataset and are illustrative.';

  AskResponse answer(AskRequest request) {
    final q = request.question.toLowerCase().trim();
    final analysisId = request.analysisId;
    final bundle = analysisId == null ? null : lookup(analysisId);

    if (q.isEmpty) {
      return const AskResponse(
        answer: 'Ask a question about the selected analysis, for example '
            '"What changed here?".',
        status: AnswerStatus.unavailable,
      );
    }
    if (bundle == null) {
      return const AskResponse(
        answer: 'No analysis is selected, so I have no records to answer '
            'from. Choose a region and hazard first.',
        status: AnswerStatus.unavailable,
      );
    }
    final a = bundle.analysis;
    if (a.status == DataStatus.notAvailable) {
      return AskResponse(
        answer: 'There is no usable data for "${a.title}". '
            '${a.statusNote ?? ''} I cannot describe change, risk or '
            'exposure here, and missing data must not be read as "safe".',
        status: AnswerStatus.unavailable,
        sources: <String>['Analysis record ${a.id}'],
      );
    }

    if (_has(q, const ['safe', 'danger', 'evacuat', 'should i', 'warning'])) {
      return _withNote(
        'I cannot judge safety or give evacuation advice. The records show '
        'observed change, preliminary estimates and potentially exposed '
        'assets only, and exposure does not confirm damage or danger. '
        'Follow official local warnings.',
        a,
        const ['Analysis record'],
      );
    }
    if (_has(q, const ['reliab', 'accura', 'valid', 'trust', 'uncertain', 'confiden'])) {
      return _reliability(bundle);
    }
    if (_has(q, const ['why', 'highlight', 'priority'])) {
      return _why(bundle, request.selectedZoneId);
    }
    if (_has(q, const ['road', 'school', 'expos', 'building', 'infrastructure',
        'communit', 'agricult', 'crop', 'population'])) {
      return _exposure(bundle, request);
    }
    if (_has(q, const ['predict', 'forecast', 'future', 'will ', 'likely',
        'probab', 'susceptib', 'risk'])) {
      return _prediction(bundle);
    }
    if (_has(q, const ['slope', 'deform', 'movement', 'displace', 'insar', 'los'])) {
      return _slope(bundle);
    }
    if (_has(q, const ['flood', 'expand', 'how much', 'area', 'km', 'inundat',
        'change', 'changed'])) {
      return _change(bundle, q);
    }
    return AskResponse(
      answer: 'I can only answer from the stored analysis records. Try: '
          '"What changed here?", "Why is this zone highlighted?", '
          '"Which roads or schools may be exposed?" or "How reliable is '
          'this estimate?".',
      status: AnswerStatus.unavailable,
      sources: <String>['Analysis record ${a.id}'],
    );
  }

  bool _has(String q, List<String> needles) {
    for (final n in needles) {
      if (q.contains(n)) return true;
    }
    return false;
  }

  AskResponse _withNote(String text, AnalysisResult a, List<String> sources,
      {AnswerStatus status = AnswerStatus.answered}) {
    final note = a.isSample ? '\n\n$_sampleNote' : '';
    return AskResponse(
      answer: '$text$note',
      status: status,
      sources: sources.map((s) => '$s (${a.id})').toList(growable: false),
    );
  }

  // --- intents ----------------------------------------------------------

  AskResponse _change(MockBundle bundle, String q) {
    final a = bundle.analysis;
    if (a.hazard == HazardType.slopeDeformation) {
      if (_has(q, const ['flood', 'expand'])) {
        return _withNote(
          'The selected analysis covers slope deformation, not flooding. '
          'Switch the hazard to "Flood expansion" to ask about flood '
          'extent.',
          a,
          const ['Analysis record'],
          status: AnswerStatus.unavailable,
        );
      }
      return _slope(bundle);
    }
    final first = a.firstObservation;
    final last = a.latestObservation;
    if (first == null || last == null || first.id == last.id) {
      return _withNote(
        'Fewer than two observations are available, so no change can be '
        'measured yet.',
        a,
        const ['Analysis record'],
        status: AnswerStatus.unavailable,
      );
    }
    final stat = a.changeFor(first.id, last.id);
    if (stat == null || stat.netChangeKm2 == null) {
      return _withNote(
        'Change statistics between ${formatDate(first.date)} and '
        '${formatDate(last.date)} are not available in the records.',
        a,
        const ['Analysis record'],
        status: AnswerStatus.unavailable,
      );
    }
    final net = stat.netChangeKm2!;
    final verb = net > 0 ? 'expanded' : (net < 0 ? 'contracted' : 'did not change');
    final days = daysBetween(first.date, last.date);
    final pct = stat.percentChange == null
        ? ''
        : ' (${formatPercent(stat.percentChange, signed: true)})';
    final range = (stat.areaBeforeKm2 != null && stat.areaAfterKm2 != null)
        ? ' from ${formatKm2(stat.areaBeforeKm2)} to '
            '${formatKm2(stat.areaAfterKm2)}'
        : '';
    final text = 'Between ${formatDate(first.date)} and ${formatDate(last.date)} '
        '($days days) the mapped flooded area $verb$range: '
        'a net change of ${formatKm2(net, signed: true)}$pct.\n\n'
        'This is an observed change between two dates. It does not show that '
        'flooding will keep spreading.';
    return _withNote(text, a, const ['Observed change statistics']);
  }

  AskResponse _slope(MockBundle bundle) {
    final a = bundle.analysis;
    final d = a.deformation;
    if (a.hazard != HazardType.slopeDeformation || d == null) {
      return _withNote(
        'The selected analysis covers flooding, so there is no slope '
        'movement record to report. Switch the hazard to "Slope '
        'deformation" and a hill region to ask about slope movement.',
        a,
        const ['Analysis record'],
        status: AnswerStatus.unavailable,
      );
    }
    final first = a.firstObservation;
    final last = a.latestObservation;
    final period = (first != null && last != null)
        ? ' between ${formatDate(first.date)} and ${formatDate(last.date)}'
        : '';
    final text = 'Line-of-sight (LOS) displacement$period reaches '
        '${formatMm(d.maxLosDisplacementMm)} at the strongest zone, with a '
        'median of ${formatMm(d.medianLosDisplacementMm)} across '
        '${d.zoneCount ?? 'the'} monitored zones.\n\n'
        '${d.losConvention}\n'
        '${d.noiseNote ?? ''}\n\n'
        'Measured displacement is not a landslide prediction.';
    return _withNote(text.trim(), a, const ['Observed deformation summary']);
  }

  AskResponse _why(MockBundle bundle, String? selectedZoneId) {
    final a = bundle.analysis;
    final zone = a.zoneById(selectedZoneId) ??
        (a.zones.isEmpty ? null : a.zonesByRank.first);
    if (zone == null) {
      return _withNote(
        'The analysis record contains no highlighted zones.',
        a,
        const ['Analysis record'],
        status: AnswerStatus.unavailable,
      );
    }
    final bullets = zone.evidence.map((e) => '- $e').join('\n');
    final basis = zone.basis == ZoneBasis.observed
        ? 'an observed zone'
        : 'an estimated (preliminary) zone';
    final text = '${zone.name} is highlighted as $basis. ${zone.summary}\n\n'
        'Evidence in the record:\n$bullets\n\n'
        'Data quality: ${zone.dataQuality ?? 'not stated'}.';
    return _withNote(text, a, const ['Zone evidence']);
  }

  AskResponse _exposure(MockBundle bundle, AskRequest request) {
    final a = bundle.analysis;
    final impact = bundle.impact;
    if (!impact.status.hasResult || impact.zoneImpacts.isEmpty) {
      return _withNote(
        'No exposure summary is available for this analysis.',
        a,
        const ['Impact record'],
        status: AnswerStatus.unavailable,
      );
    }
    final zoneImpact = impact.impactForZone(request.selectedZoneId) ??
        impact.zoneImpacts.first;
    final q = request.question.toLowerCase();
    final wanted = <AssetCategory>[
      if (q.contains('road')) AssetCategory.roads,
      if (q.contains('school')) AssetCategory.schools,
      if (q.contains('building')) AssetCategory.buildings,
      if (q.contains('agricult') || q.contains('crop')) AssetCategory.agriculture,
      if (q.contains('communit')) AssetCategory.communities,
    ];
    final categories = wanted.isEmpty ? AssetCategory.values : wanted;
    final lines = <String>[];
    for (final c in categories) {
      final e = zoneImpact.exposureFor(c);
      if (e == null || e.value == null) {
        lines.add('- ${c.label}: not available');
      } else {
        final approx = e.approximate ? '\u2248 ' : '';
        final decimals = c == AssetCategory.roads ? 1 : 0;
        lines.add('- ${c.label}: $approx${formatThousands(e.value!, decimals: decimals)} ${c.unit}');
      }
    }
    final basis = zoneImpact.basis == ZoneBasis.observed
        ? 'an observed affected area'
        : 'an estimated future-risk zone';
    final text = 'Potentially exposed assets in ${zoneImpact.zoneName} '
        '($basis):\n${lines.join('\n')}\n\n'
        '${impact.disclaimer}';
    return _withNote(text, a, const ['Impact record']);
  }

  AskResponse _reliability(MockBundle bundle) {
    final a = bundle.analysis;
    final v = bundle.validation;
    final buffer = StringBuffer();
    switch (v.status) {
      case DataStatus.available:
      case DataStatus.preliminary:
        buffer.write('Validation status: ${v.status.label.toLowerCase()}. ');
        if (v.metrics.isNotEmpty) {
          final metrics = v.metrics
              .map((m) => '${m.name} ${formatMeasure(m.value, decimals: 2, fallback: 'n/a')}')
              .join(', ');
          buffer.write('Recorded metrics: $metrics. ');
        }
        buffer.write(v.notes.join(' '));
      case DataStatus.notEvaluated:
      case DataStatus.notAvailable:
      case DataStatus.error:
        buffer.write('No validation has been performed on this analysis '
            '(status: ${v.status.label.toLowerCase()}), so its accuracy is '
            'unknown. ${v.notes.join(' ')}');
    }
    final warnings = a.qualityFlags
        .where((f) => f.level == QualityLevel.warning)
        .map((f) => '- ${f.label}: ${f.detail}')
        .toList(growable: false);
    if (warnings.isNotEmpty) {
      buffer.write('\n\nQuality warnings:\n${warnings.join('\n')}');
    }
    if (a.limitations.isNotEmpty) {
      buffer.write('\n\nKey limitation: ${a.limitations.first}');
    }
    return _withNote(buffer.toString().trim(), a,
        const ['Validation record', 'Quality flags']);
  }

  AskResponse _prediction(MockBundle bundle) {
    final a = bundle.analysis;
    final p = a.prediction;
    final what = a.hazard == HazardType.floodExpansion
        ? 'future flood expansion'
        : 'landslide susceptibility';
    if (!p.status.hasResult) {
      return _withNote(
        'There is no $what estimate for this analysis '
        '(status: ${p.status.label.toLowerCase()}). ${p.description ?? ''} '
        'A detected change does not by itself predict what happens next.',
        a,
        const ['Prediction record'],
        status: AnswerStatus.unavailable,
      );
    }
    final caveats = p.caveats.map((c) => '- $c').join('\n');
    final text = 'There is a ${p.status.label.toLowerCase()} estimate of '
        '$what: ${p.kind.label.toLowerCase()}. ${p.description ?? ''}\n\n'
        'Caveats:\n$caveats';
    return _withNote(text, a, const ['Prediction record']);
  }
}
