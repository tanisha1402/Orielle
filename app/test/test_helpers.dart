import 'package:earth_risk_chain/app/app.dart';
import 'package:earth_risk_chain/app/router.dart';
import 'package:earth_risk_chain/data/repositories/analysis_repository.dart';
import 'package:earth_risk_chain/data/repositories/mock_analysis_repository.dart';
import 'package:earth_risk_chain/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone-sized viewport (bottom navigation).
const Size phoneSize = Size(390, 844);

/// Desktop-sized viewport (navigation rail).
const Size wideSize = Size(1280, 800);

/// Pumps the whole app with a zero-latency repository and the offline
/// schematic basemap (so no test ever touches the network).
Future<void> pumpApp(
  WidgetTester tester, {
  Size size = phoneSize,
  String initialLocation = '/',
  AnalysisRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        analysisRepositoryProvider.overrideWithValue(
          repository ?? MockAnalysisRepository(latency: Duration.zero),
        ),
        basemapModeProvider.overrideWith((ref) => BasemapMode.schematic),
        routerProvider.overrideWithValue(
          createRouter(initialLocation: initialLocation),
        ),
      ],
      child: const EarthRiskChainApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds [text] only inside the screen widget of type [T] (bottom/rail
/// navigation keeps other branches alive, so plain text finders can match
/// several screens).
Finder inScreen<T extends Widget>(String text) =>
    find.descendant(of: find.byType(T), matching: find.text(text));
