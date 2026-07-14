import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_routes_state.dart';

void main() {
  group('RoutingService road helpers', () {
    final routing = RoutingService(offlineMode: true);

    test('projectOntoPolyline snaps to corridor segment', () {
      final corridor = [
        const LatLng(8.95, 125.54),
        const LatLng(8.96, 125.54),
        const LatLng(8.96, 125.55),
      ];
      final off = const LatLng(8.955, 125.541);
      final projected = routing.projectOntoPolyline(off, corridor);
      expect(projected.longitude, closeTo(125.54, 0.001));
      expect(projected.latitude, closeTo(8.955, 0.001));
    });

    test('routeThroughWaypoints returns joined points offline', () async {
      final path = await routing.routeThroughWaypoints([
        const LatLng(8.95, 125.54),
        const LatLng(8.96, 125.55),
      ]);
      expect(path.length, greaterThanOrEqualTo(2));
    });
  });

  group('VehicleRoutePreset', () {
    test('provides fare and color defaults per vehicle', () {
      final jeep = VehicleRoutePreset.forType('jeepney');
      final bus = VehicleRoutePreset.forType('bus');
      expect(jeep.suggestedBaseFare, 13);
      expect(bus.codePrefix, 'B');
      expect(bus.colorHex.startsWith('#'), isTrue);
    });
  });
}
