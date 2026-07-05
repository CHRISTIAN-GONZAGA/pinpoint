import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/candidate_route_generator.dart';
import 'package:pinpoint/features/routing/services/fare_calculator.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan_builder.dart';
import 'package:pinpoint/features/routing/services/route_assembler.dart';
import 'package:pinpoint/features/routing/services/route_ranker.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';
import 'package:pinpoint/features/routing/services/tricycle_connector.dart';
import 'package:pinpoint/features/routing/services/transfer_optimizer.dart';

List<JeepneyRoute> _loadRoutes() {
  final file = File('assets/data/routes/jeepney_routes.json');
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (root['routes'] as List)
      .map((r) => JeepneyRoute.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

void main() {
  late CandidateRouteGenerator generator;
  late List<JeepneyRoute> routes;

  setUp(() {
    routes = _loadRoutes();
    final routing = RoutingService(offlineMode: true);
    final geometry = RoutingGeometry(routing);
    generator = CandidateRouteGenerator(
      jeepneyPlans: JeepneyPlanBuilder(
        geometry: geometry,
        jeepneyPaths: JeepneyPathService(routingService: routing),
        stopMatcher: StopMatcher(geometry),
        transferOptimizer: TransferOptimizer(geometry),
      ),
      assembler: RouteAssembler(
        geometry: geometry,
        fares: FareCalculator.fromConfigs(const [
          FareConfig(transportType: 'jeepney', minimumFare: 13, succeedingRate: 1.8),
          FareConfig(transportType: 'tricycle', minimumFare: 15, succeedingRate: 2),
          FareConfig(transportType: 'taxi', minimumFare: 40, succeedingRate: 13.5),
        ]),
        tricycleConnector: TricycleConnector(geometry),
      ),
      tricycleConnector: TricycleConnector(geometry),
      ranker: const RouteRanker(),
    );
  });

  Future<void> expectJeepneyRecommended({
    required String label,
    required LatLng origin,
    required LatLng destination,
  }) async {
    final options = await generator.generate(
      origin: MapLocation(latitude: origin.latitude, longitude: origin.longitude, label: 'Origin'),
      destination: MapLocation(
        latitude: destination.latitude,
        longitude: destination.longitude,
        label: 'Destination',
      ),
      jeepneyRoutes: routes,
      tricycleZones: const [],
      highway: HighwayRestrictionService(),
    );

    expect(options, isNotEmpty, reason: '$label: no options returned');
    final hasJeepney = options.any(
      (r) => r.steps.any((s) => s.type == RouteStepType.jeepney),
    );
    expect(hasJeepney, isTrue, reason: '$label: no jeepney candidate');

    final recommended = options.firstWhere((r) => r.isRecommended);
    expect(
      recommended.primaryMode,
      anyOf(VehicleMode.jeepney, VehicleMode.walk),
      reason: '$label: recommended ${recommended.primaryMode} instead of jeepney/walk',
    );
    expect(
      recommended.primaryMode,
      isNot(VehicleMode.taxi),
      reason: '$label: taxi should not be recommended',
    );
    expect(
      recommended.primaryMode,
      isNot(VehicleMode.tricycle),
      reason: '$label: tricycle should not be recommended',
    );
  }

  test('Crossing Dumalagan to JC Aquino recommends jeepney', () async {
    await expectJeepneyRecommended(
      label: 'Dumalagan→JAQNO',
      origin: const LatLng(8.9517455, 125.46643),
      destination: const LatLng(8.9435478, 125.5230337),
    );
  });

  test('Integrated Terminal to Ampayon recommends jeepney', () async {
    await expectJeepneyRecommended(
      label: 'Terminal→Ampayon',
      origin: const LatLng(8.9600815, 125.5355754),
      destination: const LatLng(8.9617765, 125.6025052),
    );
  });

  test('Libertad to Integrated Terminal recommends jeepney', () async {
    await expectJeepneyRecommended(
      label: 'Libertad→Terminal',
      origin: const LatLng(8.9455141, 125.5011976),
      destination: const LatLng(8.9600815, 125.5355754),
    );
  });

  test('new LPTRP routes match official names', () {
    expect(routes.firstWhere((r) => r.routeCode == 'R1').routeName, 'West and East Loop');
    expect(routes.firstWhere((r) => r.routeCode == 'R2').routeName, 'City Loop via Airport');
    expect(routes.firstWhere((r) => r.routeCode == 'R3').routeName, 'Ampayon to Libertad');
  });
}
