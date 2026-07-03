import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/ai_chat/domain/chat_models.dart';

void main() {
  test('AiChatResponse parses API payload', () {
    final response = AiChatResponse.fromJson({
      'response': 'Route R2 goes to Robinsons.',
      'language': 'en',
      'session_id': 'abc-123',
      'sources': [
        {
          'title': 'R2',
          'category': 'transport',
          'score': 0.8,
          'excerpt': 'Route R2 connects...',
        },
      ],
      'actions': [
        {
          'type': 'view_on_map',
          'label': 'Robinsons',
          'latitude': 8.95,
          'longitude': 125.54,
          'place_type': 'establishment',
          'place_id': 1,
        },
      ],
      'retrieval_confidence': 0.8,
    });

    expect(response.response, contains('R2'));
    expect(response.sessionId, 'abc-123');
    expect(response.sources, hasLength(1));
    expect(response.actions.first.hasCoordinates, isTrue);
  });
}
