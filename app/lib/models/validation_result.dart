import '../core/utils/json_utils.dart';
import 'data_status.dart';

class ValidationMetric {
  const ValidationMetric({
    required this.name,
    this.value,
    this.unit,
    this.description,
  });

  final String name;

  /// `null` means not measured. Never replaced by a placeholder number.
  final double? value;
  final String? unit;
  final String? description;

  factory ValidationMetric.fromJson(Json json) => ValidationMetric(
        name: reqString(json, 'name'),
        value: optDouble(json, 'value'),
        unit: optString(json, 'unit'),
        description: optString(json, 'description'),
      );
}

/// `GET /api/v1/analyses/{id}/validation`.
class ValidationResult {
  const ValidationResult({
    required this.analysisId,
    required this.status,
    this.isSample = false,
    this.method,
    this.testPeriod,
    this.splitStrategy,
    this.metrics = const <ValidationMetric>[],
    this.notes = const <String>[],
    this.limitations = const <String>[],
  });

  final String analysisId;
  final DataStatus status;
  final bool isSample;
  final String? method;
  final String? testPeriod;
  final String? splitStrategy;
  final List<ValidationMetric> metrics;
  final List<String> notes;
  final List<String> limitations;

  factory ValidationResult.fromJson(Json json) => ValidationResult(
        analysisId: reqString(json, 'analysis_id'),
        status: DataStatus.fromApi(optString(json, 'status')),
        isSample: optBool(json, 'is_sample'),
        method: optString(json, 'method'),
        testPeriod: optString(json, 'test_period'),
        splitStrategy: optString(json, 'split_strategy'),
        metrics: mapList(json['metrics'], ValidationMetric.fromJson),
        notes: stringList(json['notes']),
        limitations: stringList(json['limitations']),
      );
}
