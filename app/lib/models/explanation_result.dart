import '../core/utils/json_utils.dart';
import 'data_status.dart';

/// A ranked contributing factor. [importance] stays `null` unless the
/// research pipeline supplied a real attribution value.
class ContributingFactor {
  const ContributingFactor({
    required this.rank,
    required this.name,
    required this.description,
    this.direction,
    this.importance,
  });

  final int rank;
  final String name;
  final String description;

  /// `increases`, `decreases` or `context`.
  final String? direction;
  final double? importance;

  factory ContributingFactor.fromJson(Json json) => ContributingFactor(
        rank: optInt(json, 'rank') ?? 99,
        name: reqString(json, 'name'),
        description: optString(json, 'description') ?? '',
        direction: optString(json, 'direction'),
        importance: optDouble(json, 'importance'),
      );
}

/// `GET /api/v1/analyses/{id}/explanation`.
class ExplanationResult {
  const ExplanationResult({
    required this.analysisId,
    required this.status,
    this.isSample = false,
    this.method,
    this.factors = const <ContributingFactor>[],
    this.caveat,
  });

  final String analysisId;
  final DataStatus status;
  final bool isSample;
  final String? method;
  final List<ContributingFactor> factors;

  /// Reminder that explanations describe associations, not causes.
  final String? caveat;

  factory ExplanationResult.fromJson(Json json) => ExplanationResult(
        analysisId: reqString(json, 'analysis_id'),
        status: DataStatus.fromApi(optString(json, 'status')),
        isSample: optBool(json, 'is_sample'),
        method: optString(json, 'method'),
        factors: mapList(json['factors'], ContributingFactor.fromJson),
        caveat: optString(json, 'caveat'),
      );
}
