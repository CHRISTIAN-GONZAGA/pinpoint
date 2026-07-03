import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/ai_chat/data/ai_history_remote_datasource.dart';

/// Persists AI chat history for registered users.
class AiHistoryRepository {
  AiHistoryRepository({
    required AiHistoryRemoteDataSource remote,
    required ApiClient apiClient,
  })  : _remote = remote,
        _apiClient = apiClient;

  final AiHistoryRemoteDataSource _remote;
  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> fetchHistory({String? sessionId}) async {
    try {
      return await _remote.fetchHistory(sessionId: sessionId);
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  Future<void> saveMessages({
    required String sessionId,
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      await _remote.saveMessages(sessionId: sessionId, messages: messages);
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }
}
