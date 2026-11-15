import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/routing/domain/transport_colors.dart';

void main() {
  test('uses the published color for each LPTRP route code', () {
    expect(TransportColors.jeepneyHex('R1'), '#E63946');
    expect(TransportColors.jeepneyHex(' R2 '), '#F4A261');
    expect(TransportColors.jeepneyHex('r3'), '#2A9D8F');
    expect(TransportColors.jeepneyHex('R4'), '#457B9D');
    expect(TransportColors.jeepneyHex('R5'), '#FB8500');
    expect(TransportColors.jeepneyHex('R6'), '#FB5607');
    expect(TransportColors.jeepneyHex('R7'), '#06D6A0');
  });

  test(
    'preserves supplied colors for unknown codes and keeps tricycle blue',
    () {
      expect(
        TransportColors.jeepneyHex('X1', fallbackHex: '#123456'),
        '#123456',
      );
      expect(TransportColors.tricycle.toARGB32(), 0xFF0EA5E9);
    },
  );
}
