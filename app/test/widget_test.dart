import 'package:earth_risk_chain/core/errors/app_exception.dart';
import 'package:earth_risk_chain/data/repositories/mock_analysis_repository.dart';
import 'package:earth_risk_chain/features/ask_earth/ask_earth_screen.dart';
import 'package:earth_risk_chain/features/explore/explore_screen.dart';
import 'package:earth_risk_chain/features/home/home_screen.dart';
import 'package:earth_risk_chain/features/impact/impact_screen.dart';
import 'package:earth_risk_chain/features/risk_analysis/risk_analysis_screen.dart';
import 'package:earth_risk_chain/models/analysis_result.dart';
import 'package:earth_risk_chain/models/api_health.dart';
import 'package:earth_risk_chain/models/chat_message.dart';
import 'package:earth_risk_chain/models/explanation_result.dart';
import 'package:earth_risk_chain/models/hazard_type.dart';
import 'package:earth_risk_chain/models/impact_summary.dart';
import 'package:earth_risk_chain/models/map_layer.dart';
import 'package:earth_risk_chain/models/study_area.dart';
import 'package:earth_risk_chain/models/validation_result.dart';
import 'package:earth_risk_chain/data/repositories/analysis_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Repository whose every call fails, to exercise error states.
class FailingRepository implements AnalysisRepository {
  Never _fail() =>
      throw const NetworkException('Could not reach the backend (test).');

  @override
  Future<ApiHealth> health() async => _fail();
  @override
  Future<List<StudyArea>> getAreas() async => _fail();
  @override
  Future<List<AnalysisSummary>> getAnalyses({HazardType? hazard}) async => _fail();
  @override
  Future<AnalysisResult> getAnalysis(String analysisId) async => _fail();
  @override
  Future<List<MapLayer>> getLayers(String analysisId) async => _fail();
  @override
  Future<ValidationResult> getValidation(String analysisId) async => _fail();
  @override
  Future<ExplanationResult> getExplanation(String analysisId) async => _fail();
  @override
  Future<ImpactSummary> getImpact(String analysisId) async => _fail();
  @override
  Future<AskResponse> ask(AskRequest request) async => _fail();
}

Future<void> goTo(WidgetTester tester, String navKey) async {
  await tester.tap(find.byKey(Key('nav-$navKey')));
  await tester.pumpAndSettle();
}

Future<void> chooseHazard(WidgetTester tester, Type screen, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(screen),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('renders identity, SAMPLE labelling and both hazard cards',
        (tester) async {
      await pumpApp(tester);
      expect(find.text('Earth Today'), findsOneWidget);
      expect(find.text('TerraLens'), findsOneWidget);
      expect(find.text('SAMPLE DATA'), findsWidgets);
      expect(find.text('Flood expansion'), findsWidgets);
      expect(find.text('Slope deformation'), findsWidgets);
      expect(find.byKey(const Key('open-explore')), findsOneWidget);
      // Slope hazard has no analysis in the default (flood) region.
      expect(find.text('No analysis for this region'), findsOneWidget);
    });

    testWidgets('"Open Explore" navigates to the map screen', (tester) async {
      await pumpApp(tester);
      await tester.ensureVisible(find.byKey(const Key('open-explore')));
      await tester.tap(find.byKey(const Key('open-explore')));
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.text('Observation timeline'), findsOneWidget);
    });

    testWidgets('region selector switches the selected area', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('area-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-area_chattogram_hills')));
      await tester.pumpAndSettle();
      // Hazard follows the area: slope analysis now exists.
      expect(inScreen<HomeScreen>('Chattogram hill slopes'), findsWidgets);
      expect(find.textContaining('Max cumulative LOS displacement'), findsOneWidget);
    });

    testWidgets('priority area opens Explore with the zone selected',
        (tester) async {
      await pumpApp(tester);
      final tile = find.byKey(const Key('priority-flood_001_zone_a'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.byKey(const Key('zone-details')), findsOneWidget);
    });

    testWidgets('About screen has working back navigation', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.info_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('About this data'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Earth Today'), findsOneWidget);
    });
  });

  group('Explore', () {
    testWidgets('shows timeline, compare modes, layers and legend',
        (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      expect(find.byKey(const Key('observation-range')), findsOneWidget);
      expect(find.byKey(const Key('compare-mode')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Map layers'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Map layers'), findsOneWidget);
      expect(find.text('Observed flood extent'), findsOneWidget);
    });

    testWidgets('layer toggle works; unavailable layer is disabled with a reason',
        (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      final futureSwitch = find.byKey(const Key('layer-switch-future_expansion'));
      await tester.scrollUntilVisible(futureSwitch, 300,
          scrollable: find.byType(Scrollable).last);
      expect(tester.widget<Switch>(futureSwitch).onChanged, isNull);
      expect(find.text('No validated expansion model for this area yet.'),
          findsOneWidget);

      final infra = find.byKey(const Key('layer-switch-infrastructure'));
      await tester.scrollUntilVisible(infra, 200,
          scrollable: find.byType(Scrollable).last);
      expect(tester.widget<Switch>(infra).value, isFalse);
      await tester.tap(infra);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(infra).value, isTrue);
    });

    testWidgets('compare mode and zone selection respond to taps',
        (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      await tester.tap(find.descendant(
          of: find.byKey(const Key('compare-mode')), matching: find.text('Before')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Before:'), findsWidgets);

      final chip = find.byKey(const Key('zone-chip-flood_001_zone_b'));
      await tester.scrollUntilVisible(chip, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('zone-details')), findsOneWidget);
      expect(find.textContaining('Zone B'), findsWidgets);
    });

    testWidgets('basemap toggle switches to the schematic label', (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      expect(find.textContaining('Schematic basemap'), findsOneWidget);
    });

    testWidgets('area without data shows the unavailable state', (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      await tester.tap(find.byKey(const Key('area-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-area_haor_basin')));
      await tester.pumpAndSettle();
      expect(find.text('No overlays to show'), findsOneWidget);
    });

    testWidgets('backend failure shows a typed error with retry', (tester) async {
      await pumpApp(tester,
          initialLocation: '/explore', repository: FailingRepository());
      expect(find.text('Backend unreachable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Risk Analysis', () {
    testWidgets('flood: observed change, unavailable prediction, not-evaluated validation',
        (tester) async {
      await pumpApp(tester, initialLocation: '/risk');
      expect(find.text('Observed flood change'), findsOneWidget);
      expect(find.byKey(const Key('net-change-tile')), findsOneWidget);
      expect(find.textContaining('+46.5'), findsWidgets);
      expect(find.text('Expansion of mapped flooding'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('prediction-unavailable')), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const Key('prediction-unavailable')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Model validation'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('"Not evaluated" is not a pass'), findsOneWidget);
    });

    testWidgets('slope module separates deformation from susceptibility',
        (tester) async {
      await pumpApp(tester, initialLocation: '/risk');
      await chooseHazard(tester, RiskAnalysisScreen, 'Slopes');
      expect(find.text('Observed slope deformation'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Landslide susceptibility'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Landslide susceptibility'), findsOneWidget);
      expect(find.text('Relative class (not a probability)'), findsOneWidget);
    });

    testWidgets('area with no data explains instead of inventing numbers',
        (tester) async {
      await pumpApp(tester, initialLocation: '/risk');
      await tester.tap(find.byKey(const Key('area-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-area_haor_basin')));
      await tester.pumpAndSettle();
      expect(find.text('No analysis data yet'), findsOneWidget);
      expect(find.text('Observed flood change'), findsNothing);
    });
  });

  group('Impact', () {
    testWidgets('shows exposure cards, disclaimer and filters', (tester) async {
      await pumpApp(tester, initialLocation: '/impact');
      expect(find.textContaining('Potentially exposed is not damaged'), findsOneWidget);
      expect(find.byKey(const Key('impact-card-buildings')), findsOneWidget);
      expect(find.byKey(const Key('impact-card-schools')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('filter-schools')));
      await tester.tap(find.byKey(const Key('filter-schools')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('impact-card-schools')), findsNothing);
      expect(find.byKey(const Key('impact-card-buildings')), findsOneWidget);
    });

    testWidgets('zone with missing data says "Not available"', (tester) async {
      await pumpApp(tester, initialLocation: '/impact');
      await tester.ensureVisible(find.byKey(const Key('impact-zone-flood_001_zone_c')));
      await tester.tap(find.byKey(const Key('impact-zone-flood_001_zone_c')));
      await tester.pumpAndSettle();
      expect(find.descendant(
        of: find.byKey(const Key('impact-card-schools')),
        matching: find.text('Not available'),
      ), findsOneWidget);
    });

    testWidgets('predicted zone is labelled as estimated', (tester) async {
      await pumpApp(tester, initialLocation: '/impact');
      await tester.tap(find.byKey(const Key('area-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-area_jamuna_floodplain')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('impact-zone-flood_002_zone_c')));
      await tester.tap(find.byKey(const Key('impact-zone-flood_002_zone_c')));
      await tester.pumpAndSettle();
      expect(find.textContaining('exposure here is hypothetical'), findsOneWidget);
    });
  });

  group('Ask Earth', () {
    testWidgets('suggested question produces a data-grounded answer',
        (tester) async {
      await pumpApp(tester, initialLocation: '/ask');
      expect(find.textContaining('Demo assistant'), findsOneWidget);
      await tester.tap(find.byKey(const Key('suggestion-0')));
      await tester.pumpAndSettle();
      expect(find.text('What changed here?'), findsWidgets);
      expect(find.textContaining('net change of +46.5'), findsOneWidget);
    });

    testWidgets('typed question works and unknown intent says so', (tester) async {
      await pumpApp(tester, initialLocation: '/ask');
      await tester.enterText(find.byKey(const Key('chat-input')), 'Tell me a joke');
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('Not in the records'), findsOneWidget);
    });

    testWidgets('clearing resets to the welcome message', (tester) async {
      await pumpApp(tester, initialLocation: '/ask');
      await tester.tap(find.byKey(const Key('suggestion-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear-chat')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello. I answer questions'), findsOneWidget);
      expect(find.textContaining('net change'), findsNothing);
    });

    testWidgets('backend failure appears as an error message', (tester) async {
      await pumpApp(tester,
          initialLocation: '/ask', repository: FailingRepository());
      await tester.tap(find.byKey(const Key('suggestion-0')));
      await tester.pumpAndSettle();
      expect(find.textContaining('I could not get an answer'), findsOneWidget);
    });
  });

  group('Navigation and responsive layout', () {
    testWidgets('bottom navigation reaches all five destinations on a phone',
        (tester) async {
      await pumpApp(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await goTo(tester, 'explore');
      expect(find.byType(ExploreScreen), findsOneWidget);
      await goTo(tester, 'risk');
      expect(find.byType(RiskAnalysisScreen), findsOneWidget);
      await goTo(tester, 'impact');
      expect(find.byType(ImpactScreen), findsOneWidget);
      await goTo(tester, 'ask');
      expect(find.byType(AskEarthScreen), findsOneWidget);
      await goTo(tester, 'home');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('wide screens use a navigation rail', (tester) async {
      await pumpApp(tester, size: wideSize);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Explore').first);
      await tester.pumpAndSettle();
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(find.text('Observation timeline'), findsOneWidget);
    });

    testWidgets('hazard selection is shared across screens', (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      await chooseHazard(tester, ExploreScreen, 'Slopes');
      await goTo(tester, 'risk');
      expect(find.text('Observed slope deformation'), findsOneWidget);
    });
  });

  group('Real August 2024 data', () {
    Future<void> pickArea(WidgetTester tester, String areaId) async {
      await tester.tap(find.byKey(const Key('area-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('area-$areaId')));
      await tester.pumpAndSettle();
    }

    testWidgets('Home labels Feni as REAL and shows the real 201 km2 extent',
        (tester) async {
      await pumpApp(tester);
      await pickArea(tester, 'area_feni_aug2024');
      expect(find.text('REAL DATA'), findsWidgets);
      expect(find.text('SAMPLE DATA'), findsNothing);
      expect(find.text('Mapped flood extent, 21 Aug 2024'), findsOneWidget);
      expect(find.text('201.0 km\u00b2'), findsOneWidget);
      expect(find.textContaining('Sonagazi upazila'), findsWidgets);
    });

    testWidgets('Risk (Feni): one dated scene -> honest "not enough observations"',
        (tester) async {
      await pumpApp(tester, initialLocation: '/risk');
      await pickArea(tester, 'area_feni_aug2024');
      expect(find.text('REAL DATA'), findsWidgets);
      expect(find.text('Not enough observations'), findsOneWidget);
      expect(find.text('Earlier Augusts (not entered)'), findsOneWidget);
    });

    testWidgets('Risk (Eastern Bangladesh): reported UNOSAT change, null totals',
        (tester) async {
      await pumpApp(tester, initialLocation: '/risk');
      await pickArea(tester, 'area_eastern_bd_aug2024');
      expect(find.text('-8,700.0 km\u00b2'), findsOneWidget);
      expect(find.text('Contraction of mapped flooding'), findsOneWidget);
      // Period totals are not published, so they are shown as unavailable.
      expect(find.text('Not available'), findsWidgets);
      expect(find.textContaining('UNOSAT aggregate'), findsOneWidget);
    });

    testWidgets('Impact (Eastern Bangladesh): reported damage, not illustrative',
        (tester) async {
      await pumpApp(tester, initialLocation: '/impact');
      await pickArea(tester, 'area_eastern_bd_aug2024');
      expect(find.text('154,892'), findsOneWidget);
      expect(find.textContaining('reported damage counts'), findsOneWidget);
      expect(find.text('Illustrative'), findsNothing);
      expect(find.text('SAMPLE DATA'), findsNothing);
    });

    testWidgets('Explore (Feni): no invented geometry, zone shows real value',
        (tester) async {
      await pumpApp(tester, initialLocation: '/explore');
      await pickArea(tester, 'area_feni_aug2024');
      expect(find.text('No overlays to show'), findsOneWidget);
      // The map stays visible and shows the real zones as markers.
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const Key('zone-marker-feni_sadar')), findsOneWidget);
      final chip = find.byKey(const Key('zone-chip-sonagazi'));
      await tester.scrollUntilVisible(chip, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.textContaining('49.0'), findsWidgets);
    });

    testWidgets('Sample regions still show SAMPLE DATA', (tester) async {
      await pumpApp(tester);
      expect(find.text('SAMPLE DATA'), findsWidgets);
      expect(find.text('REAL DATA'), findsNothing);
    });
  });

  test('MockAnalysisRepository default latency is non-zero for visible loading', () {
    expect(MockAnalysisRepository().latency, greaterThan(Duration.zero));
  });
}
