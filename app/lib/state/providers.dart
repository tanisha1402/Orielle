import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_config.dart';
import '../data/repositories/analysis_repository.dart';
import '../data/repositories/api_analysis_repository.dart';
import '../data/repositories/mock_analysis_repository.dart';
import '../data/services/api_client.dart';
import '../models/analysis_result.dart';
import '../models/data_status.dart';
import '../models/explanation_result.dart';
import '../models/hazard_type.dart';
import '../models/impact_summary.dart';
import '../models/map_layer.dart';
import '../models/study_area.dart';
import '../models/validation_result.dart';

// ---------------------------------------------------------------------------
// Dependency injection: choose the data source.
// ---------------------------------------------------------------------------

/// The single switch between SAMPLE data and the future FastAPI backend.
/// Override this provider in tests or alternative builds.
final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  if (AppConfig.useMockData) {
    return MockAnalysisRepository();
  }
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  ref.onDispose(client.close);
  return ApiAnalysisRepository(client);
});

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

final areasProvider = FutureProvider<List<StudyArea>>((ref) {
  return ref.watch(analysisRepositoryProvider).getAreas();
});

final analysisSummariesProvider = FutureProvider<List<AnalysisSummary>>((ref) {
  return ref.watch(analysisRepositoryProvider).getAnalyses();
});

// ---------------------------------------------------------------------------
// Selection (shared by all five screens)
// ---------------------------------------------------------------------------

class Selection {
  const Selection({
    this.areaId,
    this.hazard = HazardType.floodExpansion,
    this.zoneId,
  });

  /// `null` means "first available area".
  final String? areaId;
  final HazardType hazard;
  final String? zoneId;
}

class SelectionController extends Notifier<Selection> {
  @override
  Selection build() => const Selection();

  /// Selects an area. If the current hazard is not supported there, switches
  /// to the area's first supported hazard.
  void selectArea(StudyArea area) {
    var hazard = state.hazard;
    if (!area.supportedHazards.contains(hazard) &&
        area.supportedHazards.isNotEmpty) {
      hazard = area.supportedHazards.first;
    }
    state = Selection(areaId: area.id, hazard: hazard);
  }

  /// Selects a hazard. If the current area does not support it, moves to the
  /// first area that does.
  void selectHazard(HazardType hazard, List<StudyArea> areas) {
    if (areas.isEmpty) {
      state = Selection(areaId: state.areaId, hazard: hazard);
      return;
    }
    StudyArea current = areas.first;
    for (final a in areas) {
      if (a.id == state.areaId) current = a;
    }
    if (current.supportedHazards.contains(hazard)) {
      state = Selection(areaId: current.id, hazard: hazard);
      return;
    }
    for (final a in areas) {
      if (a.supportedHazards.contains(hazard)) {
        state = Selection(areaId: a.id, hazard: hazard);
        return;
      }
    }
    state = Selection(areaId: current.id, hazard: hazard);
  }

  void selectZone(String? zoneId) {
    state = Selection(
      areaId: state.areaId,
      hazard: state.hazard,
      zoneId: zoneId,
    );
  }

  /// Switches hazard (same area) and highlights a zone.
  void focusZone(HazardType hazard, String zoneId) {
    state = Selection(areaId: state.areaId, hazard: hazard, zoneId: zoneId);
  }
}

final selectionProvider =
    NotifierProvider<SelectionController, Selection>(SelectionController.new);

/// The selected area, or the first area when nothing was chosen yet.
final effectiveAreaProvider = FutureProvider<StudyArea?>((ref) async {
  final areas = await ref.watch(areasProvider.future);
  if (areas.isEmpty) return null;
  final id = ref.watch(selectionProvider.select((s) => s.areaId));
  for (final a in areas) {
    if (a.id == id) return a;
  }
  return areas.first;
});

// ---------------------------------------------------------------------------
// Analysis for the selected area + hazard
// ---------------------------------------------------------------------------

/// Summary for (selected area, [hazard]); `null` when no analysis exists.
final summaryForHazardProvider =
    FutureProvider.family<AnalysisSummary?, HazardType>((ref, hazard) async {
  final area = await ref.watch(effectiveAreaProvider.future);
  if (area == null) return null;
  final summaries = await ref.watch(analysisSummariesProvider.future);
  for (final s in summaries) {
    if (s.studyAreaId == area.id && s.hazard == hazard) return s;
  }
  return null;
});

/// Full analysis for (selected area, [hazard]).
final analysisForHazardProvider =
    FutureProvider.family<AnalysisResult?, HazardType>((ref, hazard) async {
  final summary = await ref.watch(summaryForHazardProvider(hazard).future);
  if (summary == null) return null;
  return ref.watch(analysisRepositoryProvider).getAnalysis(summary.id);
});

final currentHazardProvider = Provider<HazardType>((ref) {
  return ref.watch(selectionProvider.select((s) => s.hazard));
});

final currentSummaryProvider = FutureProvider<AnalysisSummary?>((ref) {
  final hazard = ref.watch(currentHazardProvider);
  return ref.watch(summaryForHazardProvider(hazard).future);
});

final currentAnalysisProvider = FutureProvider<AnalysisResult?>((ref) {
  final hazard = ref.watch(currentHazardProvider);
  return ref.watch(analysisForHazardProvider(hazard).future);
});

/// Layers of the current analysis. Empty when no analysis has data.
final currentLayersProvider = FutureProvider<List<MapLayer>>((ref) async {
  final summary = await ref.watch(currentSummaryProvider.future);
  if (summary == null || summary.status == DataStatus.notAvailable) {
    return const <MapLayer>[];
  }
  return ref.watch(analysisRepositoryProvider).getLayers(summary.id);
});

final currentValidationProvider = FutureProvider<ValidationResult?>((ref) async {
  final summary = await ref.watch(currentSummaryProvider.future);
  if (summary == null || summary.status == DataStatus.notAvailable) return null;
  return ref.watch(analysisRepositoryProvider).getValidation(summary.id);
});

final currentExplanationProvider =
    FutureProvider<ExplanationResult?>((ref) async {
  final summary = await ref.watch(currentSummaryProvider.future);
  if (summary == null || summary.status == DataStatus.notAvailable) return null;
  return ref.watch(analysisRepositoryProvider).getExplanation(summary.id);
});

final currentImpactProvider = FutureProvider<ImpactSummary?>((ref) async {
  final summary = await ref.watch(currentSummaryProvider.future);
  if (summary == null || summary.status == DataStatus.notAvailable) return null;
  return ref.watch(analysisRepositoryProvider).getImpact(summary.id);
});

/// Everything the Explore map needs, loaded together.
class ExploreData {
  const ExploreData({required this.analysis, required this.layers});

  final AnalysisResult analysis;
  final List<MapLayer> layers;
}

/// `null` when the selected area has no analysis for the selected hazard.
final exploreDataProvider = FutureProvider<ExploreData?>((ref) async {
  final analysis = await ref.watch(currentAnalysisProvider.future);
  if (analysis == null) return null;
  final layers = await ref.watch(currentLayersProvider.future);
  return ExploreData(analysis: analysis, layers: layers);
});

// ---------------------------------------------------------------------------
// Observation timeline, compare mode, layers, basemap
// ---------------------------------------------------------------------------

/// Indices into `AnalysisResult.observations`.
/// Flood: compare [beforeIndex] with [afterIndex].
/// Slope: only [afterIndex] is used ("as of" date).
class ObservationSelection {
  const ObservationSelection({
    required this.beforeIndex,
    required this.afterIndex,
  });

  final int beforeIndex;
  final int afterIndex;

  @override
  bool operator ==(Object other) =>
      other is ObservationSelection &&
      other.beforeIndex == beforeIndex &&
      other.afterIndex == afterIndex;

  @override
  int get hashCode => Object.hash(beforeIndex, afterIndex);
}

/// User override per analysis id (null = defaults: first -> latest).
final observationOverrideProvider =
    StateProvider.family<ObservationSelection?, String>((ref, analysisId) {
  return null;
});

int _clampIndex(int value, int max) {
  if (value < 0) return 0;
  if (value > max) return max;
  return value;
}

/// Effective selection for the current analysis (`null` without observations).
final observationSelectionProvider = Provider<ObservationSelection?>((ref) {
  final analysis = ref.watch(currentAnalysisProvider).valueOrNull;
  if (analysis == null || analysis.observations.isEmpty) return null;
  final last = analysis.observations.length - 1;
  final override = ref.watch(observationOverrideProvider(analysis.id));
  if (override == null) {
    return ObservationSelection(beforeIndex: 0, afterIndex: last);
  }
  return ObservationSelection(
    beforeIndex: _clampIndex(override.beforeIndex, last),
    afterIndex: _clampIndex(override.afterIndex, last),
  );
});

enum CompareMode {
  before('Before'),
  after('After'),
  change('Change');

  const CompareMode(this.label);
  final String label;
}

final compareModeProvider =
    StateProvider<CompareMode>((ref) => CompareMode.change);

/// User override of visible layer ids per analysis (null = layer defaults).
final layerVisibilityOverrideProvider =
    StateProvider.family<Set<String>?, String>((ref, analysisId) => null);

/// Visible layer ids given the layers and an optional user override.
Set<String> effectiveVisibleLayers(
  List<MapLayer> layers,
  Set<String>? override,
) {
  final ids = <String>{};
  for (final l in layers) {
    if (!l.isRenderable) continue;
    final on = override == null ? l.defaultVisible : override.contains(l.id);
    if (on) ids.add(l.id);
  }
  return ids;
}

enum BasemapMode { online, schematic }

final basemapModeProvider =
    StateProvider<BasemapMode>((ref) => BasemapMode.online);
