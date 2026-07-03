import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pinpoint/features/ai_chat/data/ai_local_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init('test');
  });

  group('AiLocalDataSource', () {
    test('chat returns a response from bundled knowledge', () async {
      final source = AiLocalDataSource();
      final response = await source.chat(message: 'jeepney routes in Butuan');
      expect(response.response, isNotEmpty);
      expect(response.sources, isNotEmpty);
      expect(response.retrievalConfidence, greaterThan(0));
    });

    test('chat detects tagalog prompts', () async {
      final source = AiLocalDataSource();
      final response = await source.chat(message: 'Magkano ang pamasahe sa jeep?');
      expect(response.language, 'tl');
      expect(response.response, isNotEmpty);
    });
  });
}
