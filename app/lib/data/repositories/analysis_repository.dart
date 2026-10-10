import '../../models/analysis_result.dart';
import '../../models/api_health.dart';
import '../../models/chat_message.dart';
import '../../models/explanation_result.dart';
import '../../models/hazard_type.dart';
import '../../models/impact_summary.dart';
import '../../models/map_layer.dart';
import '../../models/study_area.dart';
import '../../models/validation_result.dart';

/// Data-access contract used by every screen (through Riverpod providers).
///
/// Implementations:
/// * `MockAnalysisRepository` - deterministic SAMPLE data, no network.
/// * `ApiAnalysisRepository`  - HTTP access to the future FastAPI backend.
///
/// Every method maps to one endpoint of the integration roadmap. Methods
/// throw an `AppException` subtype on failure.
abstract class AnalysisRepository {
  /// `GET /api/v1/health`
  Future<ApiHealth> health();

  /// `GET /api/v1/areas`
  Future<List<StudyArea>> getAreas();

  /// `GET /api/v1/analyses[?hazard=flood_expansion]`
  Future<List<AnalysisSummary>> getAnalyses({HazardType? hazard});

  /// `GET /api/v1/analyses/{id}`
  Future<AnalysisResult> getAnalysis(String analysisId);

  /// `GET /api/v1/analyses/{id}/layers`
  Future<List<MapLayer>> getLayers(String analysisId);

  /// `GET /api/v1/analyses/{id}/validation`
  Future<ValidationResult> getValidation(String analysisId);

  /// `GET /api/v1/analyses/{id}/explanation`
  Future<ExplanationResult> getExplanation(String analysisId);

  /// `GET /api/v1/analyses/{id}/impact`
  Future<ImpactSummary> getImpact(String analysisId);

  /// `POST /api/v1/ask`
  Future<AskResponse> ask(AskRequest request);
}
