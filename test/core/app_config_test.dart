import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/config/app_config.dart';

void main() {
  test('AppConfig exposes API URL from compile-time environment', () {
    expect(AppConfig.apiUrl, isNotEmpty);
    expect(AppConfig.apiUrl.endsWith('/api'), isTrue);
  });
}
