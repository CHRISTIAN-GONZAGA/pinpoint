import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/authentication/presentation/viewmodels/auth_notifier.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';
import 'package:pinpoint/features/ai_chat/presentation/viewmodels/ai_chat_state.dart';
import 'package:pinpoint/features/ai_chat/presentation/viewmodels/ai_language_notifier.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Suggested prompts shown on the AI chat screen.
const aiChatSuggestions = [
  'Which jeep goes to Robinsons?',
  'Nearest hospital',
  'How much is the fare to Ampayon?',
  'Tourist attractions near me',
  'Where can I ride R3?',
  'Emergency numbers',
];

/// Manages AI chat messages and session state.
class AiChatNotifier extends Notifier<AiChatState> {
  static const _welcomeId = 'welcome';

  @override
  AiChatState build() {
    Future.microtask(_restoreHistoryIfNeeded);
    return AiChatState(
      messages: [
        ChatMessage(
          id: _welcomeId,
          content: AiResponseLanguage.welcomeMessage(
            ref.read(aiLanguageNotifierProvider),
          ),
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void refreshWelcomeMessage() {
    final language = ref.read(aiLanguageNotifierProvider);
    final messages = [...state.messages];
    final welcomeIndex = messages.indexWhere((m) => m.id == _welcomeId);
    if (welcomeIndex == -1) return;
    messages[welcomeIndex] = ChatMessage(
      id: _welcomeId,
      content: AiResponseLanguage.welcomeMessage(language),
      isUser: false,
      timestamp: messages[welcomeIndex].timestamp,
    );
    state = state.copyWith(messages: messages);
  }

  Future<void> sendMessage(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      clearError: true,
    );

    try {
      final location = ref.read(mapNotifierProvider).currentLocation;
      final responseLanguage = ref.read(aiLanguageNotifierProvider);
      final result = await ref.read(aiRepositoryProvider).chat(
            message: message,
            sessionId: state.sessionId,
            latitude: location?.latitude,
            longitude: location?.longitude,
            responseLanguage: responseLanguage,
          );

      final assistantMessage = ChatMessage(
        id: '${userMessage.id}-reply',
        content: result.response,
        isUser: false,
        sources: result.sources,
        actions: result.actions,
        language: result.language,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        sessionId: result.sessionId,
        isSending: false,
      );
      await _persistHistory(result.sessionId);
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<void> clearChat() async {
    final sessionId = state.sessionId;
    if (sessionId != null) {
      try {
        await ref.read(aiRepositoryProvider).clearSession(sessionId);
      } catch (_) {}
    }
    state = build();
  }

  Future<void> _restoreHistoryIfNeeded() async {
    if (!ref.read(isAuthenticatedProvider)) return;
    try {
      final history = await ref.read(aiHistoryRepositoryProvider).fetchHistory();
      if (history.isEmpty) return;
      final messages = history.map(_messageFromHistory).whereType<ChatMessage>().toList();
      if (messages.isEmpty) return;
      state = state.copyWith(
        messages: messages,
        sessionId: history.last['session_id'] as String?,
      );
    } catch (_) {}
  }

  Future<void> _persistHistory(String? sessionId) async {
    if (!ref.read(isAuthenticatedProvider) || sessionId == null) return;
    final payload = state.messages
        .where((message) => message.id != _welcomeId)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
            'language': message.language ?? 'en',
          },
        )
        .toList();
    if (payload.isEmpty) return;
    try {
      await ref.read(aiHistoryRepositoryProvider).saveMessages(
            sessionId: sessionId,
            messages: payload,
          );
    } catch (_) {}
  }

  ChatMessage? _messageFromHistory(Map<String, dynamic> entry) {
    final role = entry['role'] as String?;
    final content = entry['content'] as String?;
    if (role == null || content == null) return null;
    return ChatMessage(
      id: '${entry['id'] ?? content.hashCode}',
      content: content,
      isUser: role == 'user',
      timestamp: DateTime.tryParse(entry['created_at'] as String? ?? '') ?? DateTime.now(),
      language: entry['language'] as String?,
    );
  }
}

final aiChatNotifierProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);
