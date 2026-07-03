import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/accessibility/accessibility_settings.dart';

void main() {
  group('AccessibilitySettings', () {
    test('textScaleFactor increases when large text enabled', () {
      const normal = AccessibilitySettings();
      const large = AccessibilitySettings(largeText: true);
      expect(normal.textScaleFactor, 1.0);
      expect(large.textScaleFactor, 1.2);
    });

    test('toSyncPayload maps profile fields for API', () {
      const settings = AccessibilitySettings(
        largeText: true,
        reduceMotion: true,
        languageCode: 'tl',
        emergencyContactName: 'Maria',
        emergencyContactPhone: '09171234567',
      );
      final payload = settings.toSyncPayload();
      expect(payload['language_preference'], 'tl');
      expect(payload['large_text_enabled'], isTrue);
      expect(payload['reduce_motion_enabled'], isTrue);
      expect(payload['emergency_contact_name'], 'Maria');
      expect(payload['emergency_contact_phone'], '09171234567');
    });

    test('fromProfile restores settings from API response', () {
      final settings = AccessibilitySettings.fromProfile({
        'language_preference': 'ceb',
        'large_text_enabled': true,
        'reduce_motion_enabled': false,
        'emergency_contact_name': 'Juan',
      });
      expect(settings.languageCode, 'ceb');
      expect(settings.largeText, isTrue);
      expect(settings.emergencyContactName, 'Juan');
    });
  });
}
