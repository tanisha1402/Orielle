import '../core/utils/json_utils.dart';

/// Response of `GET /api/v1/health`.
class ApiHealth {
  const ApiHealth({required this.status, this.version, this.isMock = false});

  final String status;
  final String? version;

  /// True when produced by the in-app mock repository.
  final bool isMock;

  bool get isHealthy => status == 'ok';

  factory ApiHealth.fromJson(Json json) => ApiHealth(
        status: reqString(json, 'status'),
        version: optString(json, 'version'),
      );
}
