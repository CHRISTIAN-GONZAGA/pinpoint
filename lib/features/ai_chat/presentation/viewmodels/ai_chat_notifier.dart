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
    return _newConversationState();
  }

  AiChatState _newConversationState() {
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

    final history = state.messages
        .where((item) => item.id != _welcomeId)
        .map(
          (item) => {
            'role': item.isUser ? 'user' : 'assistant',
            'content': item.content,
          },
        )
        .toList();
    if (history.length > 8) {
      history.removeRange(0, history.length - 8);
    }

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
            history: history,
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
      await _persistHistory(result.sessionId, [userMessage, assistantMessage]);
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.toString().replaceFirst('AppException: ', ''),
      );
    }
  }

  Future<void> clearChat() async {
    final sessionId = state.sessionId;
    try {
      if (sessionId != null) {
        await ref.read(aiRepositoryProvider).clearSession(sessionId);
        if (ref.read(isAuthenticatedProvider)) {
          await ref.read(aiHistoryRepositoryProvider).clearSession(sessionId);
        }
      }
      state = _newConversationState();
    } catch (error) {
      state = state.copyWith(errorMessage: _displayError(error));
    }
  }

  Future<void> _restoreHistoryIfNeeded() async {
    if (!ref.read(isAuthenticatedProvider)) return;
    try {
      final history = await ref.read(aiHistoryRepositoryProvider).fetchHistory();
      if (history.isEmpty) return;
      if (state.messages.length > 1) return;
      final sessionId = history.last['session_id'] as String?;
      if (sessionId == null) return;
      final messages = history
          .where((entry) => entry['session_id'] == sessionId)
          .map(_messageFromHistory)
          .whereType<ChatMessage>()
          .toList();
      if (messages.isEmpty) return;
      state = state.copyWith(
        messages: messages,
        sessionId: sessionId,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _displayError(error));
    }
  }

  Future<void> _persistHistory(
    String? sessionId,
    List<ChatMessage> newMessages,
  ) async {
    if (!ref.read(isAuthenticatedProvider) || sessionId == null) return;
    final payload = newMessages
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
    } catch (error) {
      state = state.copyWith(errorMessage: _displayError(error));
    }
  }

  ChatMessage? _messageFromHistory(Map<String, dynamic> entry) {
    final role = entry['role'] as String?;
    final content = entry['content'] as String?;
    if (role == null || content == null) return null;
    return ChatMessage(
      id: '${entry['history_id'] ?? content.hashCode}',
      content: content,
      isUser: role == 'user',
      timestamp: DateTime.tryParse(entry['created_at'] as String? ?? '') ?? DateTime.now(),
      language: entry['language'] as String?,
    );
  }

  String _displayError(Object error) =>
      error.toString().replaceFirst('AppException: ', '');
}

final aiChatNotifierProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);
