import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_config.dart';
import '../../core/errors/app_exception.dart';

/// Thin JSON-over-HTTP transport. It knows nothing about screens or models:
/// it returns decoded JSON and throws typed [AppException]s.
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = AppConfig.apiTimeout,
  })  : _baseUrl = _normalise(baseUrl),
        _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _timeout = timeout;

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  static String _normalise(String url) {
    var out = url.trim();
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  Uri _uri(String path, Map<String, String>? query) {
    if (_baseUrl.isEmpty) {
      throw const ConfigurationException(
        'No API base URL is configured. Start the app with '
        '--dart-define=ERC_API_BASE_URL=http://host:port or keep '
        'ERC_USE_MOCK=true.',
      );
    }
    final uri = Uri.parse('$_baseUrl$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Future<Object?> getJson(String path, {Map<String, String>? query}) {
    return _send(() => _client.get(
          _uri(path, query),
          headers: const <String, String>{'Accept': 'application/json'},
        ));
  }

  Future<Object?> postJson(String path, Object body) {
    return _send(() => _client.post(
          _uri(path, null),
          headers: const <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ));
  }

  Future<Object?> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      return _decode(response);
    } on TimeoutException catch (e) {
      throw RequestTimeoutException(
        'The backend did not answer within ${_timeout.inSeconds} s.',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw NetworkException(
        'Could not reach the backend at $_baseUrl. Is it running and '
        'reachable from this device?',
        cause: e,
      );
    } on FormatException catch (e) {
      throw ParseException('The backend returned invalid JSON.', cause: e);
    }
  }

  Object? _decode(http.Response response) {
    final status = response.statusCode;
    if (status == 404) {
      throw NotFoundException(_detail(response) ?? 'Resource not found.');
    }
    if (status < 200 || status >= 300) {
      throw HttpStatusException(
        _detail(response) ?? 'Unexpected response from the backend.',
        statusCode: status,
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// FastAPI reports errors as `{"detail": "..."}`.
  String? _detail(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // Body was not JSON; fall through.
    }
    return null;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
