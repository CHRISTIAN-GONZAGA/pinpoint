import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/ai_chat/data/ai_local_datasource.dart';
import 'package:pinpoint/features/ai_chat/data/ai_remote_datasource.dart';
import 'package:pinpoint/features/ai_chat/data/ai_repository.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';
import 'package:pinpoint/features/authentication/data/auth_local_datasource.dart';

class _UnavailableRemote extends AiRemoteDataSource {
  _UnavailableRemote(ApiClient apiClient) : super(apiClient: apiClient);

  @override
  Future<AiChatResponse> sendMessage({
    required String message,
    required List<Map<String, String>> history,
    String? sessionId,
    double? latitude,
    double? longitude,
    String responseLanguage = 'auto',
  }) async {
    final request = RequestOptions(path: '/ai/chat');
    throw DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 503,
        data: {'message': 'Gemini is unavailable'},
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses the bundled keyword answer when the API returns an error',
    () async {
      final apiClient = ApiClient(
        baseUrl: 'https://example.invalid',
        authLocal: AuthLocalDataSource(),
      );
      final repository = AiRepository(
        remote: _UnavailableRemote(apiClient),
        local: AiLocalDataSource(),
        apiClient: apiClient,
      );

      final answer = await repository.chat(
        message: 'What is the jeepney fare?',
        responseLanguage: 'en',
      );

      expect(answer.response, contains('AI is unavailable right now'));
      expect(answer.response, contains('PHP 13'));
      expect(answer.sessionId, startsWith('local-'));
    },
  );
}
