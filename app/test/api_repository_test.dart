import 'dart:async';
import 'dart:convert';

import 'package:earth_risk_chain/core/errors/app_exception.dart';
import 'package:earth_risk_chain/data/repositories/api_analysis_repository.dart';
import 'package:earth_risk_chain/data/services/api_client.dart';
import 'package:earth_risk_chain/models/chat_message.dart';
import 'package:earth_risk_chain/models/hazard_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// These tests use a fake HTTP client. They verify request construction,
/// parsing and error mapping. They do NOT prove compatibility with a real
/// FastAPI backend, which does not exist yet.
ApiAnalysisRepository repoFor(MockClientHandler handler,
    {String baseUrl = 'http://api.test/', Duration? timeout}) {
  final client = ApiClient(
    baseUrl: baseUrl,
    httpClient: MockClient(handler),
    timeout: timeout ?? const Duration(seconds: 5),
  );
  return ApiAnalysisRepository(client);
}

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

void main() {
  test('getAreas accepts a bare list and an object wrapper', () async {
    final area = <String, dynamic>{
      'id': 'a',
      'name': 'Area',
      'center': <String, dynamic>{'lat': 1.0, 'lng': 2.0},
      'hazards': <String>['flood_expansion'],
    };
    var requestedPath = '';
    final bare = repoFor((req) async {
      requestedPath = req.url.path;
      return jsonResponse(<dynamic>[area]);
    });
    expect((await bare.getAreas()).single.id, 'a');
    expect(requestedPath, '/api/v1/areas');

    final wrapped =
        repoFor((req) async => jsonResponse(<String, dynamic>{'areas': <dynamic>[area]}));
    expect((await wrapped.getAreas()).single.name, 'Area');
  });

  test('getAnalyses sends the hazard query parameter', () async {
    Uri? seen;
    final repo = repoFor((req) async {
      seen = req.url;
      return jsonResponse(<dynamic>[]);
    });
    await repo.getAnalyses(hazard: HazardType.floodExpansion);
    expect(seen!.path, '/api/v1/analyses');
    expect(seen!.queryParameters['hazard'], 'flood_expansion');
  });

  test('getAnalysis parses the roadmap schema and encodes the id', () async {
    Uri? seen;
    final repo = repoFor((req) async {
      seen = req.url;
      return jsonResponse(<String, dynamic>{
        'analysis_id': 'flood demo/1',
        'hazard': 'flood_expansion',
        'study_area': 'x',
        'observation_dates': <String>['2025-06-14', '2025-07-08'],
        'prediction': <String, dynamic>{'status': 'not_available'},
        'validation': <String, dynamic>{'status': 'not_evaluated'},
      });
    });
    final a = await repo.getAnalysis('flood demo/1');
    expect(a.observations, hasLength(2));
    expect(seen!.toString(), contains('flood%20demo%2F1'));
  });

  test('layers, validation, explanation and impact hit their endpoints', () async {
    final paths = <String>[];
    final repo = repoFor((req) async {
      paths.add(req.url.path);
      if (req.url.path.endsWith('/layers')) {
        return jsonResponse(<String, dynamic>{'layers': <dynamic>[]});
      }
      return jsonResponse(<String, dynamic>{'analysis_id': 'a', 'status': 'not_evaluated'});
    });
    await repo.getLayers('a');
    await repo.getValidation('a');
    await repo.getExplanation('a');
    await repo.getImpact('a');
    expect(paths, <String>[
      '/api/v1/analyses/a/layers',
      '/api/v1/analyses/a/validation',
      '/api/v1/analyses/a/explanation',
      '/api/v1/analyses/a/impact',
    ]);
  });

  test('ask posts JSON and parses the answer', () async {
    late http.Request seen;
    final repo = repoFor((req) async {
      seen = req;
      return jsonResponse(<String, dynamic>{
        'answer': 'It changed.',
        'status': 'answered',
        'sources': <String>['record'],
      });
    });
    final r = await repo.ask(const AskRequest(question: 'What changed?', analysisId: 'a'));
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/v1/ask');
    expect(jsonDecode(seen.body)['question'], 'What changed?');
    expect(r.answer, 'It changed.');
    expect(r.sources, <String>['record']);
  });

  group('error mapping', () {
    test('404 -> NotFoundException using FastAPI detail', () async {
      final repo = repoFor((req) async =>
          jsonResponse(<String, dynamic>{'detail': 'No such analysis'}, 404));
      expect(
        repo.getAnalysis('x'),
        throwsA(isA<NotFoundException>().having((e) => e.message, 'message', 'No such analysis')),
      );
    });

    test('500 -> HttpStatusException with status code', () async {
      final repo = repoFor((req) async => http.Response('boom', 500));
      expect(
        repo.getAreas(),
        throwsA(isA<HttpStatusException>().having((e) => e.statusCode, 'status', 500)),
      );
    });

    test('invalid JSON -> ParseException', () async {
      final repo = repoFor((req) async => http.Response('not json', 200));
      expect(repo.getAreas(), throwsA(isA<ParseException>()));
    });

    test('unexpected shape -> ParseException', () async {
      final repo = repoFor((req) async => jsonResponse(<String, dynamic>{'oops': 1}));
      expect(repo.getAreas(), throwsA(isA<ParseException>()));
    });

    test('connection failure -> NetworkException', () async {
      final repo = repoFor((req) async => throw http.ClientException('refused'));
      expect(repo.getAreas(), throwsA(isA<NetworkException>()));
    });

    test('timeout -> RequestTimeoutException', () async {
      final repo = repoFor(
        (req) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(repo.getAreas(), throwsA(isA<RequestTimeoutException>()));
    });

    test('empty base URL -> ConfigurationException', () async {
      final repo = repoFor((req) async => jsonResponse(<dynamic>[]), baseUrl: '');
      expect(repo.getAreas(), throwsA(isA<ConfigurationException>()));
    });
  });
}
