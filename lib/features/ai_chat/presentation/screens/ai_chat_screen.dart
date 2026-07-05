import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';
import 'package:pinpoint/features/ai_chat/presentation/viewmodels/ai_chat_notifier.dart';
import 'package:pinpoint/features/ai_chat/presentation/viewmodels/ai_chat_state.dart';
import 'package:pinpoint/features/ai_chat/presentation/viewmodels/ai_language_notifier.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:share_plus/share_plus.dart';

/// AI transportation assistant with RAG-backed responses.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final message = text ?? _controller.text;
    if (message.trim().isEmpty) return;
    _controller.clear();
    await ref.read(aiChatNotifierProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  Future<void> _openOnMap(AiAction action) async {
    if (!action.hasCoordinates) return;
    await ref.read(mapNotifierProvider.notifier).selectDestination(
          MapLocation(
            latitude: action.latitude!,
            longitude: action.longitude!,
            label: action.label,
          ),
        );
    if (!mounted) return;
    context.go(AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatNotifierProvider);
    final responseLanguage = ref.watch(aiLanguageNotifierProvider);
    ref.listen<AiChatState>(aiChatNotifierProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Response language',
            initialValue: responseLanguage,
            onSelected: (code) async {
              await ref.read(aiLanguageNotifierProvider.notifier).setLanguage(code);
              ref.read(aiChatNotifierProvider.notifier).refreshWelcomeMessage();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'AI will reply in ${AiResponseLanguage.label(code).toLowerCase()}',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            itemBuilder: (context) {
              return AiResponseLanguage.options.map((code) {
                return PopupMenuItem<String>(
                  value: code,
                  child: Row(
                    children: [
                      if (code == responseLanguage)
                        Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(AiResponseLanguage.label(code))),
                    ],
                  ),
                );
              }).toList();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    AiResponseLanguage.shortLabel(responseLanguage),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: state.isSending
                ? null
                : () => ref.read(aiChatNotifierProvider.notifier).clearChat(),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      responseLanguage == AiResponseLanguage.auto
                          ? 'Replies match your question language'
                          : 'Replies in ${AiResponseLanguage.label(responseLanguage)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              itemCount: state.messages.length + (state.isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.messages.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: _TypingIndicator(),
                  );
                }
                final message = state.messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ChatBubble(
                    message: message,
                    onCopy: () => Clipboard.setData(ClipboardData(text: message.content)),
                    onShare: () => Share.share(message.content),
                    onViewMap: message.actions.isNotEmpty
                        ? () => _openOnMap(message.actions.first)
                        : null,
                  ),
                );
              },
            ),
          ),
          if (!state.hasMessages || state.messages.length <= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: aiChatSuggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed: state.isSending ? null : () => _send(suggestion),
                  );
                }).toList(),
              ),
            ),
          if (!state.hasMessages || state.messages.length <= 1)
            const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !state.isSending,
                    textInputAction: TextInputAction.send,
                    onSubmitted: state.isSending ? null : _send,
                    decoration: InputDecoration(
                      hintText: 'Ask about routes, fares, or places...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: state.isSending ? null : () => _send(),
                  child: state.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onCopy,
    this.onShare,
    this.onViewMap,
  });

  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.lg).copyWith(
                bottomRight: isUser ? const Radius.circular(4) : null,
                bottomLeft: !isUser ? const Radius.circular(4) : null,
              ),
            ),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? Colors.white : null,
                  ),
            ),
          ),
          if (!isUser && (message.actions.isNotEmpty || message.sources.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (onViewMap != null)
                    TextButton.icon(
                      onPressed: onViewMap,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View on Map'),
                    ),
                  if (onCopy != null)
                    IconButton(
                      tooltip: 'Copy',
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  if (onShare != null)
                    IconButton(
                      tooltip: 'Share',
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 18),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'PINPOINT is thinking...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
