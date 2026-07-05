import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan_builder.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';
import 'package:pinpoint/features/routing/services/transfer_optimizer.dart';

List<JeepneyRoute> _loadRoutes() {
  final file = File('assets/data/routes/jeepney_routes.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (root['routes'] as List)
      .map((r) => JeepneyRoute.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

void main() {
  test('R1/R2 overlap: JAQNO to Robinsons yields jeepney plans', () async {
    final routes = _loadRoutes();
    final routing = RoutingService(offlineMode: true);
    final geometry = RoutingGeometry(routing);
    final builder = JeepneyPlanBuilder(
      geometry: geometry,
      jeepneyPaths: JeepneyPathService(routingService: routing),
      stopMatcher: StopMatcher(geometry),
      transferOptimizer: TransferOptimizer(geometry),
    );

    final plans = await builder.findAllPlans(
      origin: const LatLng(8.949, 125.536),
      destination: const LatLng(8.94, 125.55),
      jeepneyRoutes: routes,
    );

    expect(plans, isNotEmpty);
    expect(
      plans.any((p) => p.boardRoute.routeCode == 'R1' || p.boardRoute.routeCode == 'R2'),
      isTrue,
    );
  });
}
