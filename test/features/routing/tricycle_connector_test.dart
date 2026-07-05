import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/tricycle_connector.dart';

TricycleZone _zone() {
  return TricycleZone.fromJson({
    'zone_id': 1,
    'zone_name': 'Zone A — City Proper',
    'polygon_geojson': {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [125.525, 8.958],
            [125.555, 8.958],
            [125.555, 8.935],
            [125.525, 8.935],
            [125.525, 8.958],
          ],
        ],
      },
    },
    'base_fare': 15.0,
    'verified': true,
  });
}

RouteStop _stop(String name, double lat, double lng) {
  return RouteStop.fromJson(
    {'id': 's1', 'name': name, 'lat': lat, 'lng': lng, 'verified': true},
    routeId: 7,
    order: 1,
  );
}

void main() {
  test('originFeeder offered when walk to PUJ stop is long', () async {
    final connector = TricycleConnector(RoutingGeometry(RoutingService(offlineMode: true)));
    final board = _stop('R7 corridor', 8.9475, 125.5406);
    final origin = const LatLng(8.9520, 125.5280);

    final feeder = await connector.originFeeder(
      origin: origin,
      boardStop: board,
      zones: [_zone()],
    );

    expect(feeder, isNotNull);
    expect(feeder!.purpose, FeederPurpose.toJeepneyStop);
  });

  test('originFeeder skipped for short walk to PUJ stop', () async {
    final connector = TricycleConnector(RoutingGeometry(RoutingService(offlineMode: true)));
    final board = _stop('Near stop', 8.9476, 125.5407);
    final origin = const LatLng(8.9475, 125.5406);

    final feeder = await connector.originFeeder(
      origin: origin,
      boardStop: board,
      zones: [_zone()],
    );

    expect(feeder, isNull);
  });
}
