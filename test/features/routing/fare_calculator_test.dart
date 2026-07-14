import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/fare_calculator.dart';

void main() {
  group('FareCalculator corridorFare', () {
    final fares = FareCalculator.fromConfigs(const []);

    test('uses per-route base and additional fare when set', () {
      const route = JeepneyRoute(
        routeId: 99,
        routeCode: 'B1',
        routeName: 'Bus One',
        colorHex: '#8338EC',
        polyline: [LatLng(8.9, 125.5), LatLng(8.91, 125.51)],
        vehicleType: 'bus',
        baseFare: 20,
        additionalFare: 3,
      );

      expect(fares.corridorFare(route, 3000), 20);
      expect(fares.corridorFare(route, 6000), 20 + (2 * 3));
    });

    test('falls back to jeepney matrix for jeepney routes', () {
      const route = JeepneyRoute(
        routeId: 1,
        routeCode: 'R1',
        routeName: 'R1',
        colorHex: '#E63946',
        polyline: [LatLng(8.9, 125.5), LatLng(8.91, 125.51)],
      );
      expect(fares.corridorFare(route, 2000), fares.jeepneyFare(2000));
    });
  });

  group('VehicleTypeMapping', () {
    test('maps vehicle types to step types', () {
      expect(VehicleTypeMapping.stepType('bus'), RouteStepType.bus);
      expect(VehicleTypeMapping.stepType('van'), RouteStepType.van);
      expect(VehicleTypeMapping.stepType('modern_jeepney'), RouteStepType.modernJeepney);
      expect(VehicleTypeMapping.stepType('jeepney'), RouteStepType.jeepney);
    });
  });
}
