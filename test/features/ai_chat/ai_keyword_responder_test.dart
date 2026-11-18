import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/ai_chat/data/ai_keyword_responder.dart';

void main() {
  group('AiKeywordResponder', () {
    test('answers common PINPOINT questions without a live AI service', () {
      final prompts = [
        'emergency numbers',
        'How much is the jeepney fare?',
        'tricycle fare',
        'taxi fare',
        'tourist attractions in Butuan',
        'Which jeep route is R3?',
        'How do I get to Bancasi airport?',
        'How do I plan a route?',
        'Where is Robinsons?',
        'Is there live traffic?',
        'How do I change my profile?',
        'What can you help me with?',
      ];

      for (final prompt in prompts) {
        expect(
          AiKeywordResponder.respond(prompt, 'en'),
          startsWith('AI is unavailable right now.'),
          reason: prompt,
        );
      }
    });

    test('provides saved route and fare facts', () {
      expect(
        AiKeywordResponder.respond('Tell me about R3', 'en'),
        contains('Ampayon to Libertad'),
      );
      expect(
        AiKeywordResponder.respond('jeepney fare', 'en'),
        contains('PHP 13'),
      );
    });

    test('answers in the selected language', () {
      expect(
        AiKeywordResponder.respond('emergency numbers', 'tl'),
        contains('Tumawag sa 911'),
      );
      expect(
        AiKeywordResponder.unknown('ceb'),
        contains('Makatabang gihapon ko'),
      );
    });

    test('does not imply live data is available', () {
      expect(
        AiKeywordResponder.respond('What is the weather?', 'en'),
        contains('does not include live weather'),
      );
    });
  });
}
