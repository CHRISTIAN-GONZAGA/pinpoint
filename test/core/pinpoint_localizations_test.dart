import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/localization/pinpoint_localizations.dart';

void main() {
  test('PinpointLocalizations returns Tagalog strings', () {
    expect(PinpointLocalizations.t('sign_in', 'tl'), 'Mag-sign In');
    expect(PinpointLocalizations.t('cached_routes', 'ceb'), 'Mga Na-save nga Ruta');
  });

  test('PinpointLocalizations falls back to English', () {
    expect(PinpointLocalizations.t('profile', 'xx'), 'Profile');
  });
}
