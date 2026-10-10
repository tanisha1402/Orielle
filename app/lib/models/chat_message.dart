import '../core/utils/json_utils.dart';

enum ChatRole { user, assistant }

/// Outcome of an Ask Earth answer.
enum AnswerStatus {
  answered('answered'),
  unavailable('unavailable'),
  error('error');

  const AnswerStatus(this.apiValue);
  final String apiValue;

  static AnswerStatus fromApi(String? value) {
    for (final s in AnswerStatus.values) {
      if (s.apiValue == value) return s;
    }
    return AnswerStatus.answered;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.status = AnswerStatus.answered,
    this.sources = const <String>[],
    this.contextLabel,
  });

  final String id;
  final ChatRole role;
  final String text;
  final AnswerStatus status;

  /// Records the answer was built from.
  final List<String> sources;

  /// Which analysis the answer refers to.
  final String? contextLabel;

  bool get isUser => role == ChatRole.user;
}

/// Body of `POST /api/v1/ask`.
class AskRequest {
  const AskRequest({
    required this.question,
    this.analysisId,
    this.selectedZoneId,
  });

  final String question;
  final String? analysisId;
  final String? selectedZoneId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'question': question,
        'analysis_id': analysisId,
        'selected_zone_id': selectedZoneId,
      };
}

/// Response of `POST /api/v1/ask`.
class AskResponse {
  const AskResponse({
    required this.answer,
    this.status = AnswerStatus.answered,
    this.sources = const <String>[],
  });

  final String answer;
  final AnswerStatus status;
  final List<String> sources;

  factory AskResponse.fromJson(Json json) => AskResponse(
        answer: reqString(json, 'answer'),
        status: AnswerStatus.fromApi(optString(json, 'status')),
        sources: stringList(json['sources']),
      );
}
