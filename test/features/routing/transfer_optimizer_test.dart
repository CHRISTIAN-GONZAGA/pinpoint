import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/transfer_optimizer.dart';

JeepneyRoute _route({
  required int id,
  required String code,
  required List<RouteStop> stops,
  required List<List<double>> coords,
}) {
  return JeepneyRoute.fromJson({
    'route_id': id,
    'code': code,
    'name': code,
    'color': '#000000',
    'ordered_stops': stops
        .map(
          (s) => {
            'id': s.stopKey,
            'name': s.name,
            'lat': s.latitude,
            'lng': s.longitude,
            'verified': s.verified,
          },
        )
        .toList(),
    'corridor_geojson': {
      'type': 'LineString',
      'coordinates': coords,
    },
  });
}

RouteStop _stop({
  required String id,
  required String name,
  required double lat,
  required double lng,
}) {
  return RouteStop.fromJson(
    {'id': id, 'name': name, 'lat': lat, 'lng': lng, 'verified': true},
    routeId: 0,
    order: 1,
  );
}

void main() {
  late TransferOptimizer optimizer;

  setUp(() {
    optimizer = TransferOptimizer(RoutingGeometry(RoutingService()));
  });

  test('allows R1/R2 transfer at co-located Libertad hub', () {
    final r1 = _route(
      id: 1,
      code: 'R1',
      stops: [
        _stop(id: 'r1_libertad', name: 'Libertad', lat: 8.9385, lng: 125.5455),
        _stop(id: 'r1_robinsons', name: 'Robinsons', lat: 8.94, lng: 125.55),
      ],
      coords: [
        [125.5455, 8.9385],
        [125.55, 8.94],
      ],
    );
    final r2 = _route(
      id: 2,
      code: 'R2',
      stops: [
        _stop(id: 'r2_libertad', name: 'Libertad', lat: 8.9385, lng: 125.5455),
        _stop(id: 'r2_jaqno', name: 'JAQNO', lat: 8.949, lng: 125.536),
      ],
      coords: [
        [125.5455, 8.9385],
        [125.536, 8.949],
      ],
    );

    final transfer = optimizer.bestTransfer(r1, r2);
    expect(transfer, isNotNull);
    expect(transfer!.originStop.stopKey, 'r1_libertad');
    expect(transfer.destStop.stopKey, 'r2_libertad');
  });

  test('rejects same-name stops that are not physically co-located (R1/R2 overlap)', () {
    final r1 = _route(
      id: 1,
      code: 'R1',
      stops: [
        _stop(id: 'r1_libertad', name: 'Libertad', lat: 8.9385, lng: 125.5455),
      ],
      coords: [
        [125.5455, 8.9385],
        [125.55, 8.94],
      ],
    );
    final r2 = _route(
      id: 2,
      code: 'R2',
      stops: [
        // Same display name but far from R1 Libertad — must not pair by name alone.
        _stop(id: 'r2_libertad_far', name: 'Libertad', lat: 8.955, lng: 125.520),
        _stop(id: 'r2_jaqno', name: 'JAQNO', lat: 8.949, lng: 125.536),
      ],
      coords: [
        [125.520, 8.955],
        [125.536, 8.949],
      ],
    );

    final transfer = optimizer.bestTransfer(r1, r2);
    expect(transfer, isNull);
  });
}
