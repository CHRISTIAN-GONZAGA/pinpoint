import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';

List<JeepneyRoute> _loadBundledRoutes() {
  final file = File('assets/data/routes/jeepney_routes.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (root['routes'] as List)
      .map((r) => JeepneyRoute.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

void main() {
  late List<JeepneyRoute> routes;
  late StopMatcher matcher;

  setUp(() {
    routes = _loadBundledRoutes();
    matcher = StopMatcher(RoutingGeometry(RoutingService()));
  });

  test('bundled data contains all 7 LPTRP routes', () {
    expect(routes.length, 7);
    expect(routes.map((r) => r.routeCode).toSet(), {'R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7'});
  });

  for (final code in ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7']) {
    test('$code is routable with verified termini', () {
      final route = routes.firstWhere((r) => r.routeCode == code);
      expect(route.isRoutable, isTrue, reason: '$code needs >= 2 verified stops');
      expect(route.verifiedStops.every((s) => s.verified), isTrue);

      final terminus = route.verifiedStops.first;
      final point = LatLng(terminus.latitude, terminus.longitude);
      final serving = matcher.routesServing(point, routes);
      expect(serving.any((r) => r.routeCode == code), isTrue);
    });
  }
}
