import 'package:earth_risk_chain/data/mock/real_aug2024_data.dart';
import 'package:earth_risk_chain/data/repositories/mock_analysis_repository.dart';
import 'package:earth_risk_chain/models/chat_message.dart';
import 'package:earth_risk_chain/models/data_status.dart';
import 'package:earth_risk_chain/models/impact_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the REAL August 2024 figures to the published sources
/// (see docs/real_data_aug2024.md) and checks that nothing was invented.
void main() {
  final repo = MockAnalysisRepository(latency: Duration.zero);

  group('Feni District (Uddin et al. 2025, Sentinel-1, 21 Aug 2024)', () {
    test('district total and acquisition date', () async {
      final a = await repo.getAnalysis(RealAug2024Data.feniAnalysisId);
      expect(a.isSample, isFalse);
      expect(a.observations, hasLength(1));
      expect(a.observations.single.date, DateTime(2024, 8, 21));
      expect(a.observations.single.floodExtentKm2, 201.0);
      expect(a.observations.single.sensor, contains('20240821T120417'));
    });

    test('six upazila values match the paper and sum to the 201 km2 total',
        () async {
      final a = await repo.getAnalysis(RealAug2024Data.feniAnalysisId);
      final byName = <String, double>{
        for (final z in a.zones) z.name: z.valuesByObservation['obs_0']!,
      };
      expect(byName['Sonagazi upazila'], 49);
      expect(byName['Chhagalnaiya upazila'], 37);
      expect(byName['Fulgazi upazila'], 35);
      expect(byName['Feni Sadar upazila'], 33);
      expect(byName['Parshuram upazila'], 31);
      expect(byName['Daganbhuiyan upazila'], 16);
      final sum = byName.values.fold<double>(0, (s, v) => s + v);
      expect(sum, a.observations.single.floodExtentKm2);
    });

    test('2022/2023 values are NOT entered as dated observations', () async {
      final a = await repo.getAnalysis(RealAug2024Data.feniAnalysisId);
      expect(a.observations.every((o) => o.date.year == 2024), isTrue);
      expect(a.changeStats, isEmpty);
      expect(a.qualityFlags.map((f) => f.detail).join(' '), contains('27 km'));
    });

    test('no fabricated geometry or exposure', () async {
      expect(await repo.getLayers(RealAug2024Data.feniAnalysisId), isEmpty);
      final impact = await repo.getImpact(RealAug2024Data.feniAnalysisId);
      expect(impact.status, DataStatus.notAvailable);
      expect(impact.zoneImpacts, isEmpty);
    });
  });

  group('Eastern Bangladesh (UNOSAT FL20240825BGD + World Bank GRADE)', () {
    test('only the reported change is entered; period totals stay null',
        () async {
      final a = await repo.getAnalysis(RealAug2024Data.easternAnalysisId);
      expect(a.isSample, isFalse);
      expect(a.status, DataStatus.preliminary);
      expect(a.observations, hasLength(2));
      expect(a.observations.every((o) => o.floodExtentKm2 == null), isTrue);
      final stat = a.changeFor('obs_0', 'obs_1')!;
      expect(stat.netChangeKm2, -8700.0);
      expect(stat.areaBeforeKm2, isNull);
      expect(stat.areaAfterKm2, isNull);
      expect(stat.percentChange, isNull);
      final text = a.qualityFlags.map((f) => f.detail).join(' ');
      expect(text, contains('8,100'));
      expect(text, contains('6.2 million'));
    });

    test('district figures match Tables 3 and 4 of the GRADE report', () async {
      final impact = await repo.getImpact(RealAug2024Data.easternAnalysisId);
      double? v(String zone, AssetCategory c) =>
          impact.impactForZone(zone)!.exposureFor(c)!.value;
      expect(v('noakhali', AssetCategory.buildings), 154892);
      expect(v('noakhali', AssetCategory.roads), 5545);
      expect(v('noakhali', AssetCategory.schools), 1107);
      expect(v('cumilla', AssetCategory.buildings), 82755);
      expect(v('cumilla', AssetCategory.roads), 3648);
      expect(v('cumilla', AssetCategory.schools), 854);
      expect(v('feni', AssetCategory.buildings), 64415);
      expect(v('feni', AssetCategory.roads), 1871);
      expect(v('feni', AssetCategory.schools), 598);
      // Cropland per district is not in the source: stays null.
      expect(v('noakhali', AssetCategory.agriculture), isNull);
      expect(v('all_flooded_areas', AssetCategory.agriculture), 2000000);
      // Nothing is labelled illustrative or approximate when it is a count.
      for (final z in impact.zoneImpacts) {
        for (final e in z.exposures) {
          expect(e.isIllustrative, isFalse);
        }
      }
      expect(impact.impactForZone('feni')!
          .exposureFor(AssetCategory.buildings)!.approximate, isFalse);
    });

    test('zones are ranked by GRADE damage and carry the affected population',
        () async {
      final a = await repo.getAnalysis(RealAug2024Data.easternAnalysisId);
      final ranked = a.zonesByRank.map((z) => z.id).toList();
      expect(ranked.take(3), <String>['noakhali', 'cumilla', 'feni']);
      expect(a.zoneById('noakhali')!.evidence.join(' '), contains('2,125,500'));
      expect(a.zoneById('cumilla')!.evidence.join(' '), contains('1,090,592'));
      expect(a.zoneById('feni')!.evidence.join(' '), contains('1,000,000'));
    });

    test('every real record cites sources and bundles no layers', () async {
      for (final id in <String>[
        RealAug2024Data.feniAnalysisId,
        RealAug2024Data.easternAnalysisId,
        RealAug2024Data.nationalAnalysisId,
        RealAug2024Data.sceneAnalysisId,
      ]) {
        final a = await repo.getAnalysis(id);
        expect(a.dataSources, isNotEmpty);
        expect(a.limitations, isNotEmpty);
        expect(await repo.getLayers(id), isEmpty);
        expect(a.prediction.status, DataStatus.notAvailable);
        expect(a.validationStatus, DataStatus.notEvaluated);
      }
    });
  });

  group('Screenshot figures: 9 vs 21 Aug 2024 (source NOT verified)', () {
    test('flooded area, change and percentage are consistent', () async {
      final a = await repo.getAnalysis(RealAug2024Data.nationalAnalysisId);
      expect(a.isSample, isFalse);
      expect(a.observations.map((o) => o.floodExtentKm2),
          <double?>[34696.0, 39576.0]);
      expect(a.observations.first.date, DateTime(2024, 8, 9));
      expect(a.observations.last.date, DateTime(2024, 8, 21));
      final c = a.changeFor('obs_0', 'obs_1')!;
      expect(c.netChangeKm2, 4880.0);
      expect(c.areaAfterKm2! - c.areaBeforeKm2!, c.netChangeKm2);
      expect(c.percentChange, closeTo(14.06, 0.01));
    });

    test('five districts ranked by rise in exposed population', () async {
      final a = await repo.getAnalysis(RealAug2024Data.nationalAnalysisId);
      final ranked = a.zonesByRank.map((z) => z.id).toList();
      expect(ranked.take(5), <String>[
        'bd_mymensingh',
        'bd_cumilla',
        'bd_noakhali',
        'bd_brahmanbaria',
        'bd_kishoreganj',
      ]);
      expect(a.zoneById('bd_mymensingh')!.evidence.join(' '),
          contains('518,000'));
    });

    test('flooded cropland is the only exposure value', () async {
      final impact = await repo.getImpact(RealAug2024Data.nationalAnalysisId);
      final all = impact.impactForZone('bd_all_extent')!;
      expect(all.exposureFor(AssetCategory.agriculture)!.value, 3460600.0);
      expect(all.exposureFor(AssetCategory.buildings)!.value, isNull);
      expect(impact.impactForZone('bd_cumilla')!
          .exposureFor(AssetCategory.agriculture)!.value, isNull);
    });

    test('the record warns that its source is unverified', () async {
      final a = await repo.getAnalysis(RealAug2024Data.nationalAnalysisId);
      expect(a.qualityFlags.map((f) => f.label), contains('Source not verified'));
    });
  });

  group('Screenshot figures: water area per scene (source NOT verified)', () {
    test('eight scenes with the transcribed areas', () async {
      final a = await repo.getAnalysis(RealAug2024Data.sceneAnalysisId);
      expect(a.observations, hasLength(8));
      final byScene = <String, double?>{
        for (final o in a.observations) o.label: o.floodExtentKm2,
      };
      expect(byScene, <String, double?>{
        '3069': 540,
        '400F': 6486,
        'BA9A': 394,
        'FD77': 1953,
        '4CBE': 128,
        'B137': 6665,
        '157B': 1194,
        '0450': 2203,
      });
      expect(a.changeStats, isEmpty);
    });

    test('zones carry the same value as their scene and rank by area',
        () async {
      final a = await repo.getAnalysis(RealAug2024Data.sceneAnalysisId);
      expect(a.zonesByRank.first.id, 'scene_b137');
      expect(a.zoneById('scene_b137')!.valuesByObservation['obs_5'], 6665);
      expect(a.zonesByRank.last.id, 'scene_4cbe');
    });
  });

  group('Ask Earth on real records', () {
    test('change answer has no sample note and no "from Not available"',
        () async {
      final r = await repo.ask(const AskRequest(
          question: 'What changed here?',
          analysisId: RealAug2024Data.easternAnalysisId));
      expect(r.status, AnswerStatus.answered);
      expect(r.answer, contains('-8,700.0 km'));
      expect(r.answer, isNot(contains('Not available')));
      expect(r.answer, isNot(contains('SAMPLE')));
    });

    test('exposure answer quotes the reported figures and the disclaimer',
        () async {
      final r = await repo.ask(const AskRequest(
          question: 'Which roads or schools may be exposed?',
          analysisId: RealAug2024Data.easternAnalysisId,
          selectedZoneId: 'noakhali'));
      expect(r.answer, contains('5,545.0 km'));
      expect(r.answer, contains('1,107 schools'));
      expect(r.answer, contains('reported damage counts'));
    });

    test('single-scene Feni record says change cannot be measured', () async {
      final r = await repo.ask(const AskRequest(
          question: 'What changed here?',
          analysisId: RealAug2024Data.feniAnalysisId));
      expect(r.status, AnswerStatus.unavailable);
    });
  });
}
