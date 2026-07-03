import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/candidate_route_generator.dart';
import 'package:pinpoint/features/routing/services/fare_calculator.dart';
import 'package:pinpoint/features/routing/services/jeepney_corridor_analyzer.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan_builder.dart';
import 'package:pinpoint/features/routing/services/route_assembler.dart';
import 'package:pinpoint/features/routing/services/route_ranker.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';
import 'package:pinpoint/features/routing/services/tricycle_connector.dart';
import 'package:pinpoint/features/routing/services/transfer_optimizer.dart';

/// Orchestrates multimodal route planning via modular services.
class RoutePlannerService {
  RoutePlannerService({
    RoutingService? routingService,
    JeepneyPathService? jeepneyPaths,
    HighwayRestrictionService? highwayService,
  })  : _routing = routingService ?? RoutingService(),
        _jeepneyPaths = jeepneyPaths ?? JeepneyPathService(),
        _highway = highwayService;

  final RoutingService _routing;
  final JeepneyPathService _jeepneyPaths;
  final HighwayRestrictionService? _highway;

  /// Plans all viable routes and ranks them for comparison.
  Future<List<PlannedRoute>> planRouteOptions({
    required MapLocation origin,
    required MapLocation destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required List<TricycleZone> tricycleZones,
    required List<FareConfig> fares,
    VehicleMode preferredMode = VehicleMode.auto,
    RoutePreference preference = RoutePreference.balanced,
  }) async {
    final highway = _highway ?? await HighwayRestrictionService.load();
    final geometry = RoutingGeometry(_routing);
    final tricycleConnector = TricycleConnector(geometry);
    final generator = CandidateRouteGenerator(
      jeepneyPlans: JeepneyPlanBuilder(
        geometry: geometry,
        jeepneyPaths: _jeepneyPaths,
        stopMatcher: StopMatcher(geometry),
        transferOptimizer: TransferOptimizer(geometry),
      ),
      assembler: RouteAssembler(
        geometry: geometry,
        fares: FareCalculator.fromConfigs(fares),
        tricycleConnector: tricycleConnector,
      ),
      tricycleConnector: tricycleConnector,
      ranker: const RouteRanker(),
    );

    return generator.generate(
      origin: origin,
      destination: destination,
      jeepneyRoutes: jeepneyRoutes,
      tricycleZones: tricycleZones,
      highway: highway,
      preference: preference,
      preferredMode: preferredMode,
    );
  }

  /// Backward-compatible single-route entry (best ranked option).
  Future<PlannedRoute> planRoute({
    required MapLocation origin,
    required MapLocation destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required List<TricycleZone> tricycleZones,
    required List<FareConfig> fares,
    VehicleMode mode = VehicleMode.auto,
    RoutePreference preference = RoutePreference.balanced,
  }) async {
    final options = await planRouteOptions(
      origin: origin,
      destination: destination,
      jeepneyRoutes: jeepneyRoutes,
      tricycleZones: tricycleZones,
      fares: fares,
      preferredMode: mode,
      preference: preference,
    );
    return options.first;
  }

  /// Returns routes whose corridors are near a point (for map context).
  List<JeepneyRoute> corridorsNear(
    List<JeepneyRoute> routes,
    double latitude,
    double longitude,
  ) {
    final geometry = RoutingGeometry(_routing);
    final analyzer = JeepneyCorridorAnalyzer(geometry);
    return analyzer
        .corridorsNear(
          LatLng(latitude, longitude),
          routes,
        )
        .map((c) => c.route)
        .toList();
  }
}
