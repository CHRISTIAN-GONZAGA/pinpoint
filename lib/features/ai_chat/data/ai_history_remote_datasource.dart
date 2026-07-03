import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';

class AiHistoryRemoteDataSource {
  AiHistoryRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<List<Map<String, dynamic>>> fetchHistory({String? sessionId}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/ai/history',
      queryParameters: sessionId != null ? {'session_id': sessionId} : null,
    );
    final list = response.data?['messages'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> saveMessages({
    required String sessionId,
    required List<Map<String, dynamic>> messages,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/ai/history',
      data: {'session_id': sessionId, 'messages': messages},
    );
  }
}
