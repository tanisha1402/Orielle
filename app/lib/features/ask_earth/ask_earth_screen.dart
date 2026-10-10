import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/color_utils.dart';
import '../../core/widgets/badges.dart';
import '../../core/widgets/panels.dart';
import '../../models/analysis_result.dart';
import '../../models/chat_message.dart';
import '../../state/providers.dart';
import '../common/scope_bar.dart';
import 'chat_controller.dart';

/// Screen 5 - Ask Earth (local demo answers, no AI model).
class AskEarthScreen extends ConsumerStatefulWidget {
  const AskEarthScreen({super.key});

  @override
  ConsumerState<AskEarthScreen> createState() => _AskEarthScreenState();
}

class _AskEarthScreenState extends ConsumerState<AskEarthScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    ref.listen<ChatState>(chatControllerProvider, (prev, next) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Earth'),
        actions: <Widget>[
          IconButton(
            key: const Key('clear-chat'),
            tooltip: 'Clear conversation',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: chat.isSending
                ? null
                : () => ref.read(chatControllerProvider.notifier).clear(),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: Column(
          children: <Widget>[
            const _ContextHeader(),
            Expanded(
              child: ListView(
                key: const Key('chat-list'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: <Widget>[
                  for (final m in chat.messages) _MessageBubble(message: m),
                  if (chat.isSending) const _TypingIndicator(),
                ],
              ),
            ),
            _SuggestedPrompts(enabled: !chat.isSending, onPick: _send),
            _InputBar(
              controller: _input,
              enabled: !chat.isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextHeader extends ConsumerWidget {
  const _ContextHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(currentSummaryProvider);
    final String label = summary.when(
      loading: () => 'Loading context...',
      error: (Object e, StackTrace s) => 'Context unavailable',
      data: (AnalysisSummary? s) =>
          s == null ? 'No analysis for this region and hazard' : s.title,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Theme(
            data: theme.copyWith(dividerColor: const Color(0x00000000)),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text('Answering from', style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary, letterSpacing: 1)),
              subtitle: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall),
              children: const <Widget>[
                ScopeBar(padding: EdgeInsets.only(bottom: 8)),
              ],
            ),
          ),
          SampleDataBanner(
            message: (ref.watch(effectiveAreaProvider).valueOrNull?.isSample ??
                    true)
                ? 'Demo assistant: answers are composed from stored SAMPLE '
                    'records by simple rules. It is not an AI model and '
                    'cannot judge safety.'
                : 'Demo assistant: answers are composed from the stored real '
                    'historical records by simple rules. It is not an AI '
                    'model and cannot judge safety.',
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isError = message.status == AnswerStatus.error;
    final isUnavailable = message.status == AnswerStatus.unavailable;
    final borderColor = isError
        ? AppColors.danger
        : (isUnavailable ? AppColors.warning : AppColors.navy500);
    final bubble = Container(
      key: Key('message-${message.id}'),
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser ? AppColors.teal700 : AppColors.navy700,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser
            ? null
            : Border.all(color: withFraction(borderColor, 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isUser && (isError || isUnavailable))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tag(
                label: isError ? 'Error' : 'Not in the records',
                color: isError ? AppColors.danger : AppColors.warning,
                icon: isError ? Icons.error_outline : Icons.search_off,
              ),
            ),
          SelectableText(message.text, style: theme.textTheme.bodyMedium),
          if (message.sources.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('Based on: ${message.sources.join(', ')}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
          if (message.contextLabel != null) ...<Widget>[
            const SizedBox(height: 2),
            Text('Context: ${message.contextLabel}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.textMuted)),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.teal700,
              child: Icon(Icons.public, size: 18, color: AppColors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('typing-indicator'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 40),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('Looking through the records...',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SuggestedPrompts extends StatelessWidget {
  const _SuggestedPrompts({required this.enabled, required this.onPick});

  final bool enabled;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: suggestedQuestions.length,
        separatorBuilder: (BuildContext c, int i) => const SizedBox(width: 8),
        itemBuilder: (BuildContext c, int i) {
          final q = suggestedQuestions[i];
          return ActionChip(
            key: Key('suggestion-$i'),
            label: Text(q),
            onPressed: enabled ? () => onPick(q) : null,
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                decoration: const InputDecoration(
                  hintText: 'Ask about change, risk or exposure',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('chat-send'),
              tooltip: 'Send',
              onPressed: enabled ? () => onSend(controller.text) : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
