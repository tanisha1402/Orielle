import '../../core/errors/app_exception.dart';
import '../../core/utils/json_utils.dart';
import '../../models/analysis_result.dart';
import '../../models/api_health.dart';
import '../../models/chat_message.dart';
import '../../models/explanation_result.dart';
import '../../models/hazard_type.dart';
import '../../models/impact_summary.dart';
import '../../models/map_layer.dart';
import '../../models/study_area.dart';
import '../../models/validation_result.dart';
import '../services/api_client.dart';
import 'analysis_repository.dart';

/// HTTP implementation of [AnalysisRepository] for the future FastAPI service.
///
/// STATUS: implemented against the documented contract
/// (`docs/api_contract.md`) and covered by unit tests with a fake HTTP
/// client. It has NOT been exercised against a real backend, because none
/// exists yet. It is only used when the app is started with
/// `--dart-define=ERC_USE_MOCK=false`.
///
/// List endpoints may return either a bare JSON array or an object wrapping
/// the array (`{"areas": [...]}`); both are accepted.
class ApiAnalysisRepository implements AnalysisRepository {
  ApiAnalysisRepository(this._client);

  final ApiClient _client;

  static const String _base = '/api/v1';

  String _id(String analysisId) => Uri.encodeComponent(analysisId);

  /// Returns the list inside [body], which is either the list itself or an
  /// object holding it under [key].
  List<Object?> _items(Object? body, String key) {
    if (body is List) return body;
    if (body is Map && body[key] is List) return body[key] as List<Object?>;
    throw ParseException('Expected a list (or an object with "$key").');
  }

  @override
  Future<ApiHealth> health() async =>
      ApiHealth.fromJson(asJson(await _client.getJson('$_base/health')));

  @override
  Future<List<StudyArea>> getAreas() async {
    final body = await _client.getJson('$_base/areas');
    return _items(body, 'areas')
        .map((e) => StudyArea.fromJson(asJson(e)))
        .toList(growable: false);
  }

  @override
  Future<List<AnalysisSummary>> getAnalyses({HazardType? hazard}) async {
    final body = await _client.getJson(
      '$_base/analyses',
      query: hazard == null
          ? null
          : <String, String>{'hazard': hazard.apiValue},
    );
    return _items(body, 'analyses')
        .map((e) => AnalysisSummary.fromJson(asJson(e)))
        .toList(growable: false);
  }

  @override
  Future<AnalysisResult> getAnalysis(String analysisId) async {
    final body = await _client.getJson('$_base/analyses/${_id(analysisId)}');
    return AnalysisResult.fromJson(asJson(body));
  }

  @override
  Future<List<MapLayer>> getLayers(String analysisId) async {
    final body =
        await _client.getJson('$_base/analyses/${_id(analysisId)}/layers');
    return _items(body, 'layers')
        .map((e) => MapLayer.fromJson(asJson(e)))
        .toList(growable: false);
  }

  @override
  Future<ValidationResult> getValidation(String analysisId) async {
    final body =
        await _client.getJson('$_base/analyses/${_id(analysisId)}/validation');
    return ValidationResult.fromJson(asJson(body));
  }

  @override
  Future<ExplanationResult> getExplanation(String analysisId) async {
    final body =
        await _client.getJson('$_base/analyses/${_id(analysisId)}/explanation');
    return ExplanationResult.fromJson(asJson(body));
  }

  @override
  Future<ImpactSummary> getImpact(String analysisId) async {
    final body =
        await _client.getJson('$_base/analyses/${_id(analysisId)}/impact');
    return ImpactSummary.fromJson(asJson(body));
  }

  @override
  Future<AskResponse> ask(AskRequest request) async {
    final body = await _client.postJson('$_base/ask', request.toJson());
    return AskResponse.fromJson(asJson(body));
  }
}
