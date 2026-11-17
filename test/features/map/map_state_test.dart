import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_state.dart';

void main() {
  test('route option selection is cleared when options are cleared', () {
    const state = MapState(selectedRouteOptionId: 'route-1');

    final next = state.copyWith(clearRouteOptions: true);

    expect(next.selectedRouteOptionId, isNull);
  });

  test('route option selection is stored explicitly', () {
    const state = MapState();

    final next = state.copyWith(selectedRouteOptionId: 'route-2');

    expect(next.selectedRouteOptionId, 'route-2');
  });
}
