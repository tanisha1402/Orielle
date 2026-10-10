import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../models/chat_message.dart';
import '../../state/providers.dart';

/// Suggested prompts shown above the input field.
const List<String> suggestedQuestions = <String>[
  'What changed here?',
  'How much did the flood expand?',
  'What slope movement was detected?',
  'Why is this zone highlighted?',
  'Which roads or schools may be exposed?',
  'How reliable is this estimate?',
];

class ChatState {
  const ChatState({required this.messages, this.isSending = false});

  final List<ChatMessage> messages;
  final bool isSending;

  ChatState copyWith({List<ChatMessage>? messages, bool? isSending}) =>
      ChatState(
        messages: messages ?? this.messages,
        isSending: isSending ?? this.isSending,
      );
}

const ChatMessage _welcome = ChatMessage(
  id: 'welcome',
  role: ChatRole.assistant,
  text: 'Hello. I answer questions from the stored analysis records of the '
      'selected region and hazard: observed change, estimates, exposure and '
      'reliability. If a record does not exist I will say so instead of '
      'guessing.',
);

/// Holds the conversation and sends questions through the repository.
class ChatController extends Notifier<ChatState> {
  int _counter = 0;

  @override
  ChatState build() => const ChatState(messages: <ChatMessage>[_welcome]);

  String _nextId() => 'm${_counter++}';

  void _append(ChatMessage message) {
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, message],
    );
  }

  /// Sends [text]. Ignored while another question is in flight.
  Future<void> send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.isSending) return;

    _append(ChatMessage(id: _nextId(), role: ChatRole.user, text: question));
    state = state.copyWith(isSending: true);

    try {
      final summary = await ref.read(currentSummaryProvider.future);
      final zoneId = ref.read(selectionProvider).zoneId;
      final response = await ref.read(analysisRepositoryProvider).ask(
            AskRequest(
              question: question,
              analysisId: summary?.id,
              selectedZoneId: zoneId,
            ),
          );
      _append(ChatMessage(
        id: _nextId(),
        role: ChatRole.assistant,
        text: response.answer,
        status: response.status,
        sources: response.sources,
        contextLabel: summary?.title,
      ));
    } catch (e) {
      final error = AppException.wrap(e);
      _append(ChatMessage(
        id: _nextId(),
        role: ChatRole.assistant,
        text: 'I could not get an answer: ${error.message}',
        status: AnswerStatus.error,
      ));
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  /// Resets the conversation to the welcome message.
  void clear() {
    state = const ChatState(messages: <ChatMessage>[_welcome]);
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
