import '../../core/errors/app_exception.dart';
import '../../models/analysis_result.dart';
import '../../models/api_health.dart';
import '../../models/chat_message.dart';
import '../../models/explanation_result.dart';
import '../../models/hazard_type.dart';
import '../../models/impact_summary.dart';
import '../../models/map_layer.dart';
import '../../models/study_area.dart';
import '../../models/validation_result.dart';
import '../mock/mock_ask_engine.dart';
import '../mock/mock_data.dart';
import 'analysis_repository.dart';

/// Serves the deterministic SAMPLE dataset from memory.
///
/// [latency] simulates a network round trip so loading states are visible in
/// the demo. Tests pass `Duration.zero`.
class MockAnalysisRepository implements AnalysisRepository {
  MockAnalysisRepository({
    this.latency = const Duration(milliseconds: 250),
    MockAskEngine? askEngine,
  }) : _askEngine = askEngine ?? const MockAskEngine();

  final Duration latency;
  final MockAskEngine _askEngine;

  Future<T> _respond<T>(T Function() build) async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    return build();
  }

  MockBundle _bundle(String analysisId) {
    final bundle = MockData.bundleFor(analysisId);
    if (bundle == null) {
      throw NotFoundException('No sample analysis with id "$analysisId".');
    }
    return bundle;
  }

  @override
  Future<ApiHealth> health() =>
      _respond(() => const ApiHealth(status: 'ok', version: 'mock', isMock: true));

  @override
  Future<List<StudyArea>> getAreas() => _respond(() => MockData.areas);

  @override
  Future<List<AnalysisSummary>> getAnalyses({HazardType? hazard}) {
    return _respond(() {
      return MockData.bundles
          .map((b) => b.summary)
          .where((s) => hazard == null || s.hazard == hazard)
          .toList(growable: false);
    });
  }

  @override
  Future<AnalysisResult> getAnalysis(String analysisId) =>
      _respond(() => _bundle(analysisId).analysis);

  @override
  Future<List<MapLayer>> getLayers(String analysisId) =>
      _respond(() => _bundle(analysisId).layers);

  @override
  Future<ValidationResult> getValidation(String analysisId) =>
      _respond(() => _bundle(analysisId).validation);

  @override
  Future<ExplanationResult> getExplanation(String analysisId) =>
      _respond(() => _bundle(analysisId).explanation);

  @override
  Future<ImpactSummary> getImpact(String analysisId) =>
      _respond(() => _bundle(analysisId).impact);

  @override
  Future<AskResponse> ask(AskRequest request) =>
      _respond(() => _askEngine.answer(request));
}
