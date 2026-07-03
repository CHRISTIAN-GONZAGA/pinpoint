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
  static const maxDetourRatio = 3.5;
  static const jeepneySpeedMps = 200 / 60;
  static const maxPlans = 24;
  static const minJeepneyLegMeters = 40.0;

  Future<List<JeepneyPlan>> findAllPlans({
    required LatLng origin,
    required LatLng destination,
    required List<JeepneyRoute> jeepneyRoutes,
  }) async {
    if (jeepneyRoutes.isEmpty) return [];

    final routable = jeepneyRoutes.where((r) => r.isRoutable).toList();
    if (routable.isEmpty) return [];

    final directMeters = _geometry.distanceMeters(origin, destination);
    final scored = <({double score, JeepneyPlan plan})>[];

    final servingOrigin = _stops.routesServing(origin, routable);
    final servingDest = _stops.routesServing(destination, routable);
    final activeRoutes = <JeepneyRoute>{
      ...servingOrigin,
      ...servingDest,
      ...routable,
    }.toList();

    for (final route in activeRoutes) {
      scored.addAll(await _sameRoutePlans(
        route: route,
        origin: origin,
        destination: destination,
        directMeters: directMeters,
      ));
    }

    for (var i = 0; i < activeRoutes.length; i++) {
      for (var j = 0; j < activeRoutes.length; j++) {
        if (i == j) continue;
        final transferPlan = await _transferPlan(
          originRoute: activeRoutes[i],
          destRoute: activeRoutes[j],
          origin: origin,
          destination: destination,
          directMeters: directMeters,
        );
        if (transferPlan != null) scored.add(transferPlan);
      }
    }

    if (scored.isEmpty) {
      scored.addAll(await _fallbackPlans(
        origin: origin,
        destination: destination,
        jeepneyRoutes: routable,
        directMeters: directMeters,
      ));
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
    if (roadPoly.length < 2 && route.verifiedStops.length < 2) return [];

    final polyline = roadPoly.length >= 2 ? roadPoly : route.polyline;
    final boardCandidates = _stops.nearbyStopsOnRoute(route, origin);
    final alightCandidates = _stops.nearbyStopsOnRoute(route, destination);

    if (boardCandidates.isEmpty || alightCandidates.isEmpty) return [];

    final results = <({double score, JeepneyPlan plan})>[];

    for (final board in boardCandidates) {
      for (final alight in alightCandidates) {
        if (board.stopId == alight.stopId) continue;

        final plan = await _trySameRoutePair(
          route: route,
          polyline: polyline,
          board: board,
          alight: alight,
          origin: origin,
          destination: destination,
          directMeters: directMeters,
        );
        if (plan != null) results.add(plan);
      }
    }
    return results;
  }

  Future<({double score, JeepneyPlan plan})?> _trySameRoutePair({
    required JeepneyRoute route,
    required List<LatLng> polyline,
    required RouteStop board,
    required RouteStop alight,
    required LatLng origin,
    required LatLng destination,
    required double directMeters,
  }) async {
    final walkToBoard = _geometry.distanceMeters(origin, board.latLng);
    final walkFromAlight = _geometry.distanceMeters(alight.latLng, destination);
    if (walkToBoard > StopMatcher.maxWalkToStopMeters + 400) return null;
    if (walkFromAlight > StopMatcher.maxWalkToStopMeters + 400) return null;

    final segment = _geometry.sliceBetweenPoints(polyline, board.latLng, alight.latLng);
    final jeepDist = _geometry.polylineLengthMeters(segment);
    if (jeepDist < minJeepneyLegMeters) return null;

    final total = walkToBoard + jeepDist + walkFromAlight;
    if (!_passesDetourCheck(total, directMeters)) return null;

    final walkTo = await _geometry.safeWalkingRoute(origin, board.latLng);
    final walkFrom = await _geometry.safeWalkingRoute(alight.latLng, destination);
    final jeepDuration = (jeepDist / jeepneySpeedMps).round();

    final suffix = board.order < alight.order ? 'fwd' : 'rev';
    final plan = JeepneyPlan(
      planId: 'jeep-${route.routeCode}-${board.stopId}-${alight.stopId}-$suffix',
      boardRoute: route,
      boardStop: board,
      alightStop: alight,
      walkToBoard: walkTo,
      walkFromAlight: walkFrom,
      jeepneyPolyline: segment,
      jeepneyDistanceMeters: jeepDist,
      jeepneyDurationSeconds: jeepDuration,
      estimatedTotalMeters: walkTo.distanceMeters + jeepDist + walkFrom.distanceMeters,
    );
    return (score: total + jeepDist * 0.08, plan: plan);
  }

  bool _passesDetourCheck(double totalMeters, double directMeters) {
    if (directMeters < 400) {
      return totalMeters <= directMeters * 4.5;
    }
    if (directMeters < walkOnlyMaxMeters) {
      return totalMeters <= directMeters * 2.8;
    }
    if (directMeters < 5000) {
      return totalMeters <= directMeters * maxDetourRatio;
    }
    return totalMeters <= directMeters * (maxDetourRatio + 0.5);
  }

  Future<List<({double score, JeepneyPlan plan})>> _fallbackPlans({
    required LatLng origin,
    required LatLng destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required double directMeters,
  }) async {
    final results = <({double score, JeepneyPlan plan})>[];
    for (final route in jeepneyRoutes) {
      final board = _nearestStop(route, origin);
      final alight = _nearestStop(route, destination);
      if (board == null || alight == null || board.stopId == alight.stopId) continue;

      final polyline = route.polyline;
      if (polyline.length < 2) continue;

      final plan = await _trySameRoutePair(
        route: route,
        polyline: polyline,
        board: board,
        alight: alight,
        origin: origin,
        destination: destination,
        directMeters: directMeters,
      );
      if (plan != null) results.add(plan);
    }
    return results;
  }

  RouteStop? _nearestStop(JeepneyRoute route, LatLng point) {
    RouteStop? best;
    var bestDist = double.infinity;
    for (final stop in route.verifiedStops) {
      final d = _geometry.distanceMeters(point, stop.latLng);
      if (d < bestDist) {
        bestDist = d;
        best = stop;
      }
    }
    if (best == null || bestDist > StopMatcher.maxWalkToStopMeters + 800) return null;
    return best;
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

    final boardCandidates = _stops.nearbyStopsOnRoute(originRoute, origin, limit: 5);
    final alightCandidates = _stops.nearbyStopsOnRoute(destRoute, destination, limit: 5);
    if (boardCandidates.isEmpty || alightCandidates.isEmpty) return null;

    ({double score, JeepneyPlan plan})? best;

    for (final boardStop in boardCandidates) {
      for (final alightStop in alightCandidates) {
        final originPoly = await _jeepneyPaths.roadPolylineForRoute(originRoute);
        final destPoly = await _jeepneyPaths.roadPolylineForRoute(destRoute);
        final oPoly = originPoly.length >= 2 ? originPoly : originRoute.polyline;
        final dPoly = destPoly.length >= 2 ? destPoly : destRoute.polyline;

        final firstLeg =
            _geometry.sliceBetweenPoints(oPoly, boardStop.latLng, transfer.originStop.latLng);
        final secondLeg =
            _geometry.sliceBetweenPoints(dPoly, transfer.destStop.latLng, alightStop.latLng);
        final firstDist = _geometry.polylineLengthMeters(firstLeg);
        final secondDist = _geometry.polylineLengthMeters(secondLeg);
        if (firstDist < minJeepneyLegMeters || secondDist < minJeepneyLegMeters) continue;

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
        if (!_passesDetourCheck(total, directMeters)) continue;

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

        final score = total + 150 + transfer.walkMeters * 0.4;
        if (best == null || score < best.score) {
          best = (score: score, plan: plan);
        }
      }
    }
    return best;
  }
}
