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

    add(await _assembler.buildWalkRoute(origin: origin, destination: destination));

    final jeepneyPlanList = await _jeepneyPlans.findAllPlans(
      origin: origin.latLng,
      destination: destination.latLng,
      jeepneyRoutes: jeepneyRoutes,
    );

    for (final plan in jeepneyPlanList) {
      add(await _assembler.buildFromJeepneyPlan(
        origin: origin,
        destination: destination,
        plan: plan,
        zones: tricycleZones,
      ));

      final feeder = await _tricycle.originFeeder(
        origin: origin.latLng,
        boardStop: plan.boardStop,
        zones: tricycleZones,
      );
      if (feeder != null) {
        add(await _assembler.buildFromJeepneyPlan(
          origin: origin,
          destination: destination,
          plan: plan,
          zones: tricycleZones,
          originFeeder: feeder,
        ));
      }
    }

    final triDrive = await _assembler.buildTricycleRoute(
      origin: origin,
      destination: destination,
    );
    if (triDrive != null) {
      final polyline = triDrive.fullPolyline;
      String? warning;
      if (highway.pathUsesNationalHighway(polyline)) {
        warning =
            'Direct tricycle route crosses a national highway. Tricycles must use barangay roads only — consider Jeepney or Taxi.';
      }
      add(triDrive.copyWith(warningMessage: warning));
    }

    add(await _assembler.buildTaxiRoute(origin: origin, destination: destination));

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
