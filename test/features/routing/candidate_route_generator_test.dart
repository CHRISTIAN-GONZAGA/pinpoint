import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/candidate_route_generator.dart';
import 'package:pinpoint/features/routing/services/fare_calculator.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan_builder.dart';
import 'package:pinpoint/features/routing/services/route_assembler.dart';
import 'package:pinpoint/features/routing/services/route_ranker.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';
import 'package:pinpoint/features/routing/services/tricycle_connector.dart';
import 'package:pinpoint/features/routing/services/transfer_optimizer.dart';

void main() {
  test('labels walk/tricycle options when no jeepney corridor serves trip', () async {
    final geometry = RoutingGeometry(RoutingService());
    final jeepneyPaths = JeepneyPathService(routingService: RoutingService());
    final generator = CandidateRouteGenerator(
      jeepneyPlans: JeepneyPlanBuilder(
        geometry: geometry,
        jeepneyPaths: jeepneyPaths,
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

    // Far from any verified LPTRP corridor in bundled data.
    final origin = MapLocation(latitude: 8.88, longitude: 125.48, label: 'Remote A');
    final destination = MapLocation(latitude: 8.87, longitude: 125.47, label: 'Remote B');

    final routes = <JeepneyRoute>[];
    final zones = <TricycleZone>[];
    final highway = HighwayRestrictionService();

    final options = await generator.generate(
      origin: origin,
      destination: destination,
      jeepneyRoutes: routes,
      tricycleZones: zones,
      highway: highway,
    );

    expect(options, isNotEmpty);
    final hasJeepney = options.any(
      (r) => r.steps.any((s) => s.type == RouteStepType.jeepney),
    );
    expect(hasJeepney, isFalse);
    expect(
      options.every((r) => r.warningMessage == unservedJeepneyMessage),
      isTrue,
    );
  });
}
