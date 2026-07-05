import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan_builder.dart';
import 'package:pinpoint/features/routing/services/route_assembler.dart';
import 'package:pinpoint/features/routing/services/route_ranker.dart';
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
    final seen = <String>{};

    void add(PlannedRoute? route) {
      if (route == null || !seen.add(route.optionId)) return;
      candidates.add(route);
    }

    final walkFuture = _assembler.buildWalkRoute(origin: origin, destination: destination);
    final jeepneyPlansFuture = _jeepneyPlans.findAllPlans(
      origin: origin.latLng,
      destination: destination.latLng,
      jeepneyRoutes: jeepneyRoutes,
    );
    final tricycleFuture = _assembler.buildTricycleRoute(
      origin: origin,
      destination: destination,
    );
    final taxiFuture = _assembler.buildTaxiRoute(origin: origin, destination: destination);

    add(await walkFuture);

    final jeepneyPlanList = await jeepneyPlansFuture;

    final jeepneyAssembly = jeepneyPlanList.map((plan) async {
      final walkToBoard = plan.walkToBoard.distanceMeters;
      final longWalkToPuj = walkToBoard >= TricycleConnector.feederMinWalkMeters;

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

      // Skip long straight-line walks to PUJ when tricycle feeder is available.
      if (withFeeder != null && longWalkToPuj) {
        return [withFeeder];
      }

      final direct = await _assembler.buildFromJeepneyPlan(
        origin: origin,
        destination: destination,
        plan: plan,
        zones: tricycleZones,
      );

      if (withFeeder != null) {
        return [withFeeder, direct];
      }
      return [direct];
    });

    for (final batch in await Future.wait(jeepneyAssembly)) {
      for (final route in batch) {
        add(route);
      }
    }

    final triDrive = await tricycleFuture;
    if (triDrive != null) {
      final polyline = triDrive.fullPolyline;
      String? warning;
      if (highway.pathUsesNationalHighway(polyline)) {
        warning =
            'Direct tricycle route crosses a national highway. Tricycles must use barangay roads only — consider Jeepney or Taxi.';
      }
      add(triDrive.copyWith(warningMessage: warning));
    }

    add(await taxiFuture);

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

    final hasJeepney = ranked.any(
      (r) => r.steps.any((s) => s.type == RouteStepType.jeepney),
    );
    if (!hasJeepney) {
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
}
