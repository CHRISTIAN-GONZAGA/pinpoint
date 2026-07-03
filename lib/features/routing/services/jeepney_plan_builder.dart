import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/stop_matcher.dart';
import 'package:pinpoint/features/routing/services/transfer_optimizer.dart';

/// Enumerates all viable jeepney board/alight and transfer combinations.
class JeepneyPlanBuilder {
  JeepneyPlanBuilder({
    required RoutingGeometry geometry,
    required JeepneyPathService jeepneyPaths,
    StopMatcher? stopMatcher,
    TransferOptimizer? transferOptimizer,
  })  : _geometry = geometry,
        _jeepneyPaths = jeepneyPaths,
        _stops = stopMatcher ?? StopMatcher(geometry),
        _transfers = transferOptimizer ?? TransferOptimizer(geometry);

  final RoutingGeometry _geometry;
  final JeepneyPathService _jeepneyPaths;
  final StopMatcher _stops;
  final TransferOptimizer _transfers;

  static const walkOnlyMaxMeters = 1400.0;
  static const maxDetourRatio = 2.4;
  static const jeepneySpeedMps = 200 / 60;
  static const maxPlans = 20;

  Future<List<JeepneyPlan>> findAllPlans({
    required LatLng origin,
    required LatLng destination,
    required List<JeepneyRoute> jeepneyRoutes,
  }) async {
    final directMeters = _geometry.distanceMeters(origin, destination);
    final scored = <({double score, JeepneyPlan plan})>[];

    for (final route in jeepneyRoutes) {
      final sameRoutePlans = await _sameRoutePlans(
        route: route,
        origin: origin,
        destination: destination,
        directMeters: directMeters,
      );
      scored.addAll(sameRoutePlans);
    }

    for (var i = 0; i < jeepneyRoutes.length; i++) {
      for (var j = 0; j < jeepneyRoutes.length; j++) {
        if (i == j) continue;
        final transferPlan = await _transferPlan(
          originRoute: jeepneyRoutes[i],
          destRoute: jeepneyRoutes[j],
          origin: origin,
          destination: destination,
          directMeters: directMeters,
        );
        if (transferPlan != null) scored.add(transferPlan);
      }
    }

    scored.sort((a, b) => a.score.compareTo(b.score));

    final seen = <String>{};
    final plans = <JeepneyPlan>[];
    for (final entry in scored) {
      if (seen.add(entry.plan.planId)) plans.add(entry.plan);
      if (plans.length >= maxPlans) break;
    }
    return plans;
  }

  Future<List<({double score, JeepneyPlan plan})>> _sameRoutePlans({
    required JeepneyRoute route,
    required LatLng origin,
    required LatLng destination,
    required double directMeters,
  }) async {
    final roadPoly = await _jeepneyPaths.roadPolylineForRoute(route);
    if (roadPoly.length < 2) return [];

    final boardCandidates = _stops.nearbyStopsOnRoute(route, origin);
    final alightCandidates = _stops.nearbyStopsOnRoute(route, destination);
    final results = <({double score, JeepneyPlan plan})>[];

    for (final board in boardCandidates) {
      for (final alight in alightCandidates) {
        if (board.stopId == alight.stopId) continue;
        if (board.order >= alight.order) continue;

        final walkToBoard = _geometry.distanceMeters(origin, board.latLng);
        final walkFromAlight = _geometry.distanceMeters(alight.latLng, destination);
        final segment = _geometry.sliceBetweenPoints(roadPoly, board.latLng, alight.latLng);
        final jeepDist = _geometry.polylineLengthMeters(segment);
        if (jeepDist < 80) continue;

        final total = walkToBoard + jeepDist + walkFromAlight;
        if (total > directMeters * maxDetourRatio && directMeters < 3000) continue;
        if (directMeters <= walkOnlyMaxMeters && total > directMeters * 1.35) continue;

        final walkTo = await _geometry.safeWalkingRoute(origin, board.latLng);
        final walkFrom = await _geometry.safeWalkingRoute(alight.latLng, destination);
        final jeepDuration = (jeepDist / jeepneySpeedMps).round();

        final plan = JeepneyPlan(
          planId: 'jeep-${route.routeCode}-${board.stopId}-${alight.stopId}',
          boardRoute: route,
          boardStop: board,
          alightStop: alight,
          walkToBoard: walkTo,
          walkFromAlight: walkFrom,
          jeepneyPolyline: segment,
          jeepneyDistanceMeters: jeepDist,
          jeepneyDurationSeconds: jeepDuration,
          estimatedTotalMeters:
              walkTo.distanceMeters + jeepDist + walkFrom.distanceMeters,
        );
        results.add((score: total + jeepDist * 0.1, plan: plan));
      }
    }
    return results;
  }

  Future<({double score, JeepneyPlan plan})?> _transferPlan({
    required JeepneyRoute originRoute,
    required JeepneyRoute destRoute,
    required LatLng origin,
    required LatLng destination,
    required double directMeters,
  }) async {
    final transfer = _transfers.bestTransfer(originRoute, destRoute);
    if (transfer == null) return null;

    final boardCandidates = _stops.nearbyStopsOnRoute(originRoute, origin, limit: 4);
    final alightCandidates = _stops.nearbyStopsOnRoute(destRoute, destination, limit: 4);

    ({double score, JeepneyPlan plan})? best;

    for (final boardStop in boardCandidates) {
      if (boardStop.order >= transfer.originStop.order) continue;
      for (final alightStop in alightCandidates) {
        if (transfer.destStop.order >= alightStop.order) continue;

        final originPoly = await _jeepneyPaths.roadPolylineForRoute(originRoute);
        final destPoly = await _jeepneyPaths.roadPolylineForRoute(destRoute);

        final firstLeg =
            _geometry.sliceBetweenPoints(originPoly, boardStop.latLng, transfer.originStop.latLng);
        final secondLeg =
            _geometry.sliceBetweenPoints(destPoly, transfer.destStop.latLng, alightStop.latLng);
        final firstDist = _geometry.polylineLengthMeters(firstLeg);
        final secondDist = _geometry.polylineLengthMeters(secondLeg);
        if (firstDist < 80 || secondDist < 80) continue;

        final walkTo = await _geometry.safeWalkingRoute(origin, boardStop.latLng);
        final walkFrom = await _geometry.safeWalkingRoute(alightStop.latLng, destination);
        final transferWalk = await _geometry.safeWalkingRoute(
          transfer.originStop.latLng,
          transfer.destStop.latLng,
        );

        final total = walkTo.distanceMeters +
            firstDist +
            transfer.walkMeters +
            secondDist +
            walkFrom.distanceMeters;
        if (total > directMeters * (maxDetourRatio + 0.3)) continue;

        final plan = JeepneyPlan(
          planId:
              'xfer-${originRoute.routeCode}-${destRoute.routeCode}-${boardStop.stopId}-${alightStop.stopId}',
          boardRoute: originRoute,
          boardStop: boardStop,
          alightStop: alightStop,
          walkToBoard: walkTo,
          walkFromAlight: walkFrom,
          transferRoute: destRoute,
          transferOriginStop: transfer.originStop,
          transferDestStop: transfer.destStop,
          transferWalk: transferWalk,
          transferWalkMeters: transfer.walkMeters,
          firstLegPolyline: firstLeg,
          firstLegDistanceMeters: firstDist,
          firstLegDurationSeconds: (firstDist / jeepneySpeedMps).round(),
          secondLegPolyline: secondLeg,
          secondLegDistanceMeters: secondDist,
          secondLegDurationSeconds: (secondDist / jeepneySpeedMps).round(),
          estimatedTotalMeters: total,
        );

        final score = total + 180 + transfer.walkMeters * 0.5;
        if (best == null || score < best.score) {
          best = (score: score, plan: plan);
        }
      }
    }
    return best;
  }
}
