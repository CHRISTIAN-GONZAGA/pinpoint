import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan_builder.dart';
import 'package:pinpoint/features/routing/services/route_assembler.dart';
import 'package:pinpoint/features/routing/services/route_ranker.dart';
import 'package:pinpoint/features/routing/services/route_scorer.dart';
import 'package:pinpoint/features/routing/services/tricycle_connector.dart';

/// Generates every feasible multimodal itinerary before ranking.
class CandidateRouteGenerator {
  CandidateRouteGenerator({
    required JeepneyPlanBuilder jeepneyPlans,
    required RouteAssembler assembler,
    required TricycleConnector tricycleConnector,
    required RouteRanker ranker,
  })  : _jeepneyPlans = jeepneyPlans,
        _assembler = assembler,
        _tricycle = tricycleConnector,
        _ranker = ranker;

  final JeepneyPlanBuilder _jeepneyPlans;
  final RouteAssembler _assembler;
  final TricycleConnector _tricycle;
  final RouteRanker _ranker;

  Future<List<PlannedRoute>> generate({
    required MapLocation origin,
    required MapLocation destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required List<TricycleZone> tricycleZones,
    required HighwayRestrictionService highway,
    RoutePreference preference = RoutePreference.balanced,
    VehicleMode preferredMode = VehicleMode.auto,
  }) async {
    final candidates = <PlannedRoute>[];

    // Only active corridor routes with stops participate in public-transit planning.
    final corridorRoutes = jeepneyRoutes
        .where((r) => r.activeStatus && r.isRoutable && r.isCorridorVehicle)
        .toList();
    final hasTaxiRoutes = jeepneyRoutes.any((r) => r.vehicleType == 'taxi');
    final hasActiveTaxiService = !hasTaxiRoutes ||
        jeepneyRoutes.any((r) => r.activeStatus && r.vehicleType == 'taxi');

    final walkFuture = _assembler.buildWalkRoute(origin: origin, destination: destination);
    final jeepneyPlansFuture = _jeepneyPlans.findAllPlans(
      origin: origin.latLng,
      destination: destination.latLng,
      jeepneyRoutes: corridorRoutes,
    );
    final tricycleFuture = _assembler.buildTricycleRoute(
      origin: origin,
      destination: destination,
    );
    final taxiFuture = hasActiveTaxiService
        ? _assembler.buildTaxiRoute(origin: origin, destination: destination)
        : Future<PlannedRoute?>.value(null);

    final jeepneyPlanList = await jeepneyPlansFuture;

    final jeepneyAssembly = jeepneyPlanList.map((plan) async {
      final walkToBoard = plan.walkToBoard.distanceMeters;
      final needsFeeder = walkToBoard >= TricycleConnector.feederMinWalkMeters;

      final feeder = await _tricycle.originFeeder(
        origin: origin.latLng,
        boardStop: plan.boardStop,
        attachPoint: plan.boardPoint,
        zones: tricycleZones,
      );

      final withFeeder = feeder != null
          ? await _assembler.buildFromJeepneyPlan(
              origin: origin,
              destination: destination,
              plan: plan,
              zones: tricycleZones,
              originFeeder: feeder,
            )
          : null;

      // Always use tricycle feeder when walk to PUJ corridor would be long.
      if (withFeeder != null && needsFeeder) {
        return [withFeeder];
      }

      final direct = await _assembler.buildFromJeepneyPlan(
        origin: origin,
        destination: destination,
        plan: plan,
        zones: tricycleZones,
      );

      if (withFeeder != null && direct != null) {
        return [withFeeder, direct];
      }
      return [direct];
    });

    for (final batch in await Future.wait(jeepneyAssembly)) {
      for (final route in batch) {
        _addCandidate(candidates, route);
      }
    }

    _addCandidate(candidates, await walkFuture);

    final triDrive = await tricycleFuture;
    if (triDrive != null) {
      final polyline = triDrive.fullPolyline;
      String? warning;
      if (highway.pathUsesNationalHighway(polyline)) {
        warning =
            'Direct tricycle route crosses a national highway. Tricycles must use barangay roads only — consider Jeepney or Taxi.';
      }
      _addCandidate(candidates, triDrive.copyWith(warningMessage: warning));
    }

    _addCandidate(candidates, await taxiFuture);

    _pruneInferiorJeepneyOptions(candidates, triDrive);

    if (candidates.isEmpty) {
      final walk = await _assembler.buildWalkRoute(origin: origin, destination: destination);
      if (walk != null) {
        return [
          walk.copyWith(
            warningMessage: unservedJeepneyMessage,
            isRecommended: true,
          ),
        ];
      }
      return [];
    }

    final ranked = _ranker.rank(
      candidates: candidates,
      preference: preference,
      preferredMode: preferredMode,
    );

    ranked.sort((a, b) {
      if (a.isRecommended != b.isRecommended) return a.isRecommended ? -1 : 1;
      return (a.rankScore ?? 0).compareTo(b.rankScore ?? 0);
    });

    final hasCorridor = ranked.any(
      (r) => r.steps.any((s) => VehicleTypeMapping.isCorridorStep(s.type) &&
          s.type != RouteStepType.taxi &&
          s.type != RouteStepType.tricycle),
    );
    // Also count jeepney-like including bus/van/modern.
    final hasPublicCorridor = ranked.any(
      (r) => r.steps.any(
        (s) =>
            s.type == RouteStepType.jeepney ||
            s.type == RouteStepType.modernJeepney ||
            s.type == RouteStepType.bus ||
            s.type == RouteStepType.van,
      ),
    );
    if (!hasPublicCorridor && !hasCorridor) {
      return ranked
          .map(
            (r) => r.copyWith(
              warningMessage: r.warningMessage ?? unservedJeepneyMessage,
            ),
          )
          .toList();
    }

    return ranked;
  }

  void _addCandidate(List<PlannedRoute> list, PlannedRoute? route) {
    if (route == null) return;
    final existing = list.indexWhere((r) => r.optionId == route.optionId);
    if (existing >= 0) {
      if ((route.rankScore ?? 999) < (list[existing].rankScore ?? 999)) {
        list[existing] = route;
      }
      return;
    }
    list.add(route);
  }

  /// Drops jeepney-only options that cost more and take longer than direct tricycle
  /// on short city trips only.
  void _pruneInferiorJeepneyOptions(List<PlannedRoute> candidates, PlannedRoute? tricycle) {
    if (tricycle == null) return;
    if (tricycle.totalDistanceMeters > RouteScorer.shortTricycleBoostMeters) return;

    candidates.removeWhere((route) {
      if (!_hasPublicCorridorStep(route)) return false;

      final hasOriginFeeder = _hasOriginFeeder(route);
      if (hasOriginFeeder) return false;

      final worseFare = route.estimatedFare > tricycle.estimatedFare + 3;
      final worseTime = route.totalDurationSeconds > tricycle.totalDurationSeconds + 120;
      final longWalk = route.walkingDistanceMeters > TricycleConnector.feederMinWalkMeters;

      return worseFare && (worseTime || longWalk);
    });
  }

  bool _hasPublicCorridorStep(PlannedRoute route) => route.steps.any(
        (s) =>
            s.type == RouteStepType.jeepney ||
            s.type == RouteStepType.modernJeepney ||
            s.type == RouteStepType.bus ||
            s.type == RouteStepType.van,
      );

  bool _hasOriginFeeder(PlannedRoute route) {
    final triIdx = route.steps.indexWhere((s) => s.type == RouteStepType.tricycle);
    final jeepIdx = route.steps.indexWhere(
      (s) =>
          s.type == RouteStepType.jeepney ||
          s.type == RouteStepType.modernJeepney ||
          s.type == RouteStepType.bus ||
          s.type == RouteStepType.van,
    );
    return triIdx >= 0 && jeepIdx > triIdx;
  }
}
