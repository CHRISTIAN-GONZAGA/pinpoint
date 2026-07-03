import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';

JeepneyRoute _routeFromJson(Map<String, dynamic> json) => JeepneyRoute.fromJson(json);

void main() {
  late StopMatcher matcher;

  setUp(() {
    matcher = StopMatcher(RoutingGeometry(RoutingService()));
  });

  group('StopMatcher', () {
    test('returns R1 when origin is near verified North Montilla terminus', () {
      final route = _routeFromJson({
        'route_id': 1,
        'code': 'R1',
        'name': 'City Proper Loop',
        'color': '#1D3557',
        'bidirectional': true,
        'street_segments': ['North Montilla Blvd'],
        'ordered_stops': [
          {
            'id': 'r1_north_montilla',
            'name': 'North Montilla Blvd',
            'lat': 8.9485,
            'lng': 125.5375,
            'verified': true,
          },
          {
            'id': 'r1_libertad',
            'name': 'Libertad',
            'lat': 8.9385,
            'lng': 125.5455,
            'verified': true,
          },
        ],
        'corridor_geojson': {
          'type': 'LineString',
          'coordinates': [
            [125.5375, 8.9485],
            [125.5455, 8.9385],
          ],
        },
      });

      final point = const LatLng(8.9485, 125.5375);
      final serving = matcher.routesServing(point, [route]);
      expect(serving, contains(route));
      expect(matcher.nearbyStopsOnRoute(route, point).first.name, 'North Montilla Blvd');
    });

    test('excludes unverified stops from matcher results', () {
      final route = _routeFromJson({
        'route_id': 6,
        'code': 'R6',
        'name': 'Maguinda',
        'color': '#FFB703',
        'ordered_stops': [
          {
            'id': 'r6_maguinda',
            'name': 'Maguinda',
            'lat': null,
            'lng': null,
            'verified': false,
          },
          {
            'id': 'r6_guingona',
            'name': 'Guingona Park',
            'lat': 8.951,
            'lng': 125.532,
            'verified': true,
          },
          {
            'id': 'r6_montilla',
            'name': 'Montilla Blvd',
            'lat': 8.9485,
            'lng': 125.5375,
            'verified': true,
          },
        ],
        'corridor_geojson': {
          'type': 'LineString',
          'coordinates': [
            [125.532, 8.951],
            [125.5375, 8.9485],
          ],
        },
      });

      expect(route.isRoutable, isTrue);
      final stops = matcher.nearbyStopsOnRoute(route, const LatLng(8.951, 125.532));
      expect(stops, isNotEmpty);
      expect(stops.every((s) => s.verified), isTrue);
      expect(stops.any((s) => s.name == 'Maguinda'), isFalse);
    });
  });
}
