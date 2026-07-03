import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

void main() {
  group('FareConfig', () {
    test('computes minimum fare within 4km', () {
      const fare = FareConfig(
        transportType: 'jeepney',
        minimumFare: 13,
        succeedingRate: 1.8,
      );
      expect(fare.computeFare(3), 13);
    });

    test('adds succeeding rate beyond 4km', () {
      const fare = FareConfig(
        transportType: 'jeepney',
        minimumFare: 13,
        succeedingRate: 2,
      );
      expect(fare.computeFare(6), 17);
    });
  });

  group('JeepneyRoute', () {
    test('parses geojson polyline from API response', () {
      final route = JeepneyRoute.fromJson({
        'route_id': 1,
        'route_code': 'R1',
        'route_name': 'R1 Test',
        'color': '#E63946',
        'geojson': {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [125.53, 8.95],
              [125.54, 8.94],
            ],
          },
        },
        'stops': [],
      });
      expect(route.polyline.length, 2);
      expect(route.polyline.first.latitude, 8.95);
    });
  });
}
