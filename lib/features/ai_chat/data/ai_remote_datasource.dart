import 'package:dio/dio.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';

/// Remote API for the PINPOINT RAG assistant.
class AiRemoteDataSource {
  AiRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<AiChatResponse> sendMessage({
    required String message,
    String? sessionId,
    double? latitude,
    double? longitude,
    String responseLanguage = AiResponseLanguage.auto,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/ai/chat',
      data: {
        'message': message,
        'session_id': ?sessionId,
        'latitude': ?latitude,
        'longitude': ?longitude,
        if (responseLanguage != AiResponseLanguage.auto)
          'response_language': responseLanguage,
      },
    );
    final data = response.data;
    if (data == null) {
      throw const AppException('No response from AI assistant');
    }
    return AiChatResponse.fromJson(data);
  }

  Future<void> clearSession(String sessionId) async {
    await _api.post<Map<String, dynamic>>(
      '/ai/clear',
      data: {'session_id': sessionId},
    );
  }
}
