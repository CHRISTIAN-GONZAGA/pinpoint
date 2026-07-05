import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/ai_chat/data/ai_intent_resolver.dart';
import 'package:pinpoint/features/ai_chat/domain/ai_response_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiIntentResolver', () {
    test('responds to hello', () async {
      final reply = await AiIntentResolver.tryResolve(
        message: 'Hello',
        language: AiResponseLanguage.english,
      );
      expect(reply, isNotNull);
      expect(reply!.toLowerCase(), contains('hello'));
    });

    test('responds to where is robinsons', () async {
      final reply = await AiIntentResolver.tryResolve(
        message: 'Where is Robinsons?',
        language: AiResponseLanguage.english,
      );
      expect(reply, isNotNull);
      expect(reply!.toLowerCase(), contains('robinsons'));
      expect(reply.toLowerCase(), contains('r2'));
    });
  });
}
