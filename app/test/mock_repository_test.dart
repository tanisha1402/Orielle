import 'package:earth_risk_chain/core/errors/app_exception.dart';
import 'package:earth_risk_chain/data/mock/mock_data.dart';
import 'package:earth_risk_chain/data/repositories/mock_analysis_repository.dart';
import 'package:earth_risk_chain/models/chat_message.dart';
import 'package:earth_risk_chain/models/data_status.dart';
import 'package:earth_risk_chain/models/hazard_type.dart';
import 'package:earth_risk_chain/models/map_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = MockAnalysisRepository(latency: Duration.zero);

  test('is deterministic and lists the sample areas', () async {
    final a = await repo.getAreas();
    final b = await repo.getAreas();
    expect(a.map((e) => e.id), b.map((e) => e.id));
    // 4 SAMPLE regions + 4 regions with REAL August 2024 records.
    expect(a, hasLength(8));
    expect(a.where((e) => e.isSample), hasLength(4));
    expect(a.where((e) => !e.isSample).map((e) => e.id),
        <String>[
          'area_feni_aug2024',
          'area_eastern_bd_aug2024',
          'area_bd_extent_aug2024',
          'area_bd_scenes_aug2024',
        ]);
    // The default (first) region is still a sample region.
    expect(a.first.isSample, isTrue);
  });

  test('filters analyses by hazard', () async {
    final floods = await repo.getAnalyses(hazard: HazardType.floodExpansion);
    final slopes = await repo.getAnalyses(hazard: HazardType.slopeDeformation);
    expect(floods, hasLength(7));
    expect(slopes, hasLength(1));
    expect((await repo.getAnalyses()), hasLength(8));
  });

  test('unknown analysis id throws NotFoundException', () async {
    expect(repo.getAnalysis('nope'), throwsA(isA<NotFoundException>()));
  });

  test('every study area has exactly the analyses it advertises', () async {
    final areas = await repo.getAreas();
    final summaries = await repo.getAnalyses();
    for (final area in areas) {
      for (final h in area.supportedHazards) {
        expect(
          summaries.where((s) => s.studyAreaId == area.id && s.hazard == h),
          hasLength(1),
          reason: '${area.id} / ${h.apiValue}',
        );
      }
    }
  });

  test('sample change statistics are internally consistent', () async {
    final a = await repo.getAnalysis('flood_demo_001');
    final first = a.firstObservation!;
    final last = a.latestObservation!;
    final stat = a.changeFor(first.id, last.id)!;
    expect(stat.areaBeforeKm2, first.floodExtentKm2);
    expect(stat.areaAfterKm2, last.floodExtentKm2);
    expect(stat.netChangeKm2, closeTo(46.5, 0.001));
    // Second area expands then partly recedes: contraction between T1 and T2.
    final b = await repo.getAnalysis('flood_demo_002');
    expect(b.changeFor('obs_1', 'obs_2')!.netChangeKm2, lessThan(0));
    expect(b.changeFor('obs_0', 'obs_2')!.netChangeKm2, greaterThan(0));
  });

  test('observed, predicted and unavailable states are all represented', () async {
    final f1 = await repo.getAnalysis('flood_demo_001');
    final f2 = await repo.getAnalysis('flood_demo_002');
    final f3 = await repo.getAnalysis('flood_demo_003');
    final s1 = await repo.getAnalysis('slope_demo_001');
    expect(f1.prediction.status, DataStatus.notAvailable);
    expect(f2.prediction.status, DataStatus.preliminary);
    expect(f2.prediction.isCalibrated, isFalse);
    expect(f3.status, DataStatus.notAvailable);
    expect(f3.observations, isEmpty);
    expect(s1.deformation, isNotNull);
    expect(s1.prediction.kind.apiValue, 'relative_class');
    expect(s1.validationStatus, DataStatus.notEvaluated);
    expect((await repo.getLayers('flood_demo_003')), isEmpty);
  });

  test('layer features only reference known observations and zones', () async {
    for (final b in MockData.bundles) {
      final obsIds = b.analysis.observations.map((o) => o.id).toSet();
      final zoneIds = b.analysis.zones.map((z) => z.id).toSet();
      for (final layer in b.layers) {
        for (final f in layer.features) {
          if (f.observationId != null) expect(obsIds, contains(f.observationId));
          if (f.fromObservationId != null) expect(obsIds, contains(f.fromObservationId));
          if (f.toObservationId != null) expect(obsIds, contains(f.toObservationId));
          if (f.zoneId != null) expect(zoneIds, contains(f.zoneId));
          // Every style key resolves to a legend entry.
          if (layer.legend.isNotEmpty && f.observationId == null) {
            expect(layer.legend.map((l) => l.key), contains(f.styleKey),
                reason: '${layer.id}/${f.id}');
          }
        }
        if (layer.status == DataStatus.notAvailable) {
          expect(layer.isRenderable, isFalse);
          expect(layer.blockedReason, isNotNull);
        }
      }
    }
  });

  group('Ask engine (local demo)', () {
    Future<AskResponse> ask(String q, String? id, {String? zone}) =>
        repo.ask(AskRequest(question: q, analysisId: id, selectedZoneId: zone));

    test('answers observed change from records and warns it is not a forecast', () async {
      final r = await ask('What changed here?', 'flood_demo_001');
      expect(r.status, AnswerStatus.answered);
      expect(r.answer, contains('+46.5 km'));
      expect(r.answer, contains('does not show that flooding will keep spreading'));
      expect(r.answer, contains('SAMPLE'));
    });

    test('says so when there is no analysis or no data', () async {
      expect((await ask('What changed here?', null)).status, AnswerStatus.unavailable);
      final r = await ask('How much did the flood expand?', 'flood_demo_003');
      expect(r.status, AnswerStatus.unavailable);
      expect(r.answer, contains('must not be read as'));
    });

    test('refuses to judge safety', () async {
      final r = await ask('Is it safe to stay?', 'flood_demo_001');
      expect(r.answer, contains('cannot judge safety'));
    });

    test('reports missing prediction and missing validation honestly', () async {
      final p = await ask('Will it spread further in future?', 'flood_demo_001');
      expect(p.status, AnswerStatus.unavailable);
      final v = await ask('How reliable is this estimate?', 'flood_demo_001');
      expect(v.answer, contains('No validation has been performed'));
    });

    test('exposure answer is labelled potential and illustrative', () async {
      final r = await ask('Which roads or schools may be exposed?', 'flood_demo_001');
      expect(r.answer, contains('Roads'));
      expect(r.answer, contains('Schools'));
      expect(r.answer, contains('does not'));
    });

    test('slope question on a flood analysis is redirected', () async {
      final r = await ask('What slope movement was detected?', 'flood_demo_001');
      expect(r.status, AnswerStatus.unavailable);
    });

    test('slope answer states LOS is not a landslide prediction', () async {
      final r = await ask('What slope movement was detected?', 'slope_demo_001');
      expect(r.answer, contains('-26.3 mm'));
      expect(r.answer, contains('not a landslide prediction'));
    });

    test('unknown intent falls back to guidance', () async {
      final r = await ask('Tell me a joke', 'flood_demo_001');
      expect(r.status, AnswerStatus.unavailable);
    });
  });
}
