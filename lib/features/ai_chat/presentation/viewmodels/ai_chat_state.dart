import 'package:equatable/equatable.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';

/// UI state for the AI chat screen.
class AiChatState extends Equatable {
  const AiChatState({
    this.messages = const [],
    this.sessionId,
    this.isSending = false,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final String? sessionId;
  final bool isSending;
  final String? errorMessage;

  bool get hasMessages => messages.isNotEmpty;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      sessionId: clearSession ? null : sessionId ?? this.sessionId,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [messages, sessionId, isSending, errorMessage];
}
