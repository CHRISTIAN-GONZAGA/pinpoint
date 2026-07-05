import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';

void main() {
  group('AiResponseLanguage', () {
    test('detectFromMessage identifies Tagalog', () {
      expect(
        AiResponseLanguage.detectFromMessage('Magkano ang pamasahe sa jeep?'),
        AiResponseLanguage.tagalog,
      );
    });

    test('detectFromMessage identifies Cebuano', () {
      expect(
        AiResponseLanguage.detectFromMessage('Unsa akong sakyan padulong sa Robinson?'),
        AiResponseLanguage.cebuano,
      );
    });

    test('resolve uses explicit preference over detection', () {
      expect(
        AiResponseLanguage.resolve(
          preference: AiResponseLanguage.cebuano,
          message: 'Which jeep goes to Robinsons?',
        ),
        AiResponseLanguage.cebuano,
      );
    });

    test('resolve falls back to detection when auto', () {
      expect(
        AiResponseLanguage.resolve(
          preference: AiResponseLanguage.auto,
          message: 'Magkano ang pamasahe?',
        ),
        AiResponseLanguage.tagalog,
      );
    });
  });
}
