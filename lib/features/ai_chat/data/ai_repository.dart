import 'package:dio/dio.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/ai_chat/data/ai_local_datasource.dart';
import 'package:pinpoint/features/ai_chat/data/ai_remote_datasource.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';

/// Repository for AI chat interactions with offline-first local retrieval.
class AiRepository {
  AiRepository({
    required AiRemoteDataSource remote,
    required AiLocalDataSource local,
    required ApiClient apiClient,
  })  : _remote = remote,
        _local = local,
        _apiClient = apiClient;

  final AiRemoteDataSource _remote;
  final AiLocalDataSource _local;
  final ApiClient _apiClient;

  Future<AiChatResponse> chat({
    required String message,
    String? sessionId,
    double? latitude,
    double? longitude,
    String responseLanguage = AiResponseLanguage.auto,
  }) async {
    if (AppConstants.offlineFirstMode) {
      return _local.chat(
        message: message,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        responseLanguage: responseLanguage,
      );
    }
    try {
      return await _remote.sendMessage(
        message: message,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        responseLanguage: responseLanguage,
      );
    } on DioException catch (error) {
      try {
        return await _local.chat(
          message: message,
          sessionId: sessionId,
          latitude: latitude,
          longitude: longitude,
          responseLanguage: responseLanguage,
        );
      } catch (_) {
        throw _apiClient.mapError(error);
      }
    }
  }

  Future<void> clearSession(String sessionId) async {
    if (AppConstants.offlineFirstMode) {
      await _local.clearSession(sessionId);
      return;
    }
    try {
      await _remote.clearSession(sessionId);
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }
}
