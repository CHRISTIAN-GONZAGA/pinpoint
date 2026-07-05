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
  static const maxDetourRatio = 4.0;
  static const jeepneySpeedMps = 200 / 60;
  static const maxPlans = 32;
  static const minJeepneyLegMeters = 30.0;
  static const maxAlightToDestMeters = 1200.0;

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
      final plan = await _tryOptimalSameRoute(
        route: route,
        origin: origin,
        destination: destination,
        directMeters: directMeters,
      );
      if (plan != null) scored.add(plan);
    }

    final sameRouteCount = scored.length;
    if (sameRouteCount < 4) {
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

  /// One optimal same-route plan using corridor projection (no overshoot alight).
  Future<({double score, JeepneyPlan plan})?> _tryOptimalSameRoute({
    required JeepneyRoute route,
    required LatLng origin,
    required LatLng destination,
    required double directMeters,
  }) async {
    final roadPoly = route.polyline.length >= 2
        ? route.polyline
        : await _jeepneyPaths.roadPolylineForRoute(route);
    if (roadPoly.length < 2 && route.verifiedStops.length < 2) return null;

    final polyline = roadPoly.length >= 2 ? roadPoly : route.polyline;
    final boardProj = _geometry.projectOntoPolyline(polyline, origin);
    final alightProj = _geometry.projectOntoPolyline(polyline, destination);

    if ((boardProj.distanceFromStart - alightProj.distanceFromStart).abs() <
        minJeepneyLegMeters) {
      return null;
    }

    final boardPoint = boardProj.point;
    final alightPoint = alightProj.point;
    final alightToDest = _geometry.distanceMeters(alightPoint, destination);

    // Reject plans where the corridor alight is unreasonably far from destination.
    if (alightToDest > maxAlightToDestMeters) return null;

    final boardStop = _labelStop(route, boardPoint);
    final alightStop = _labelStop(route, alightPoint);
    if (boardStop == null || alightStop == null) return null;

    final walkToBoardDist = _geometry.distanceMeters(origin, boardPoint);
    final walkFromAlightDist = alightToDest;
    if (walkToBoardDist > StopMatcher.maxWalkToStopMeters + 400) return null;

    final segment = _geometry.sliceBetweenPoints(polyline, boardPoint, alightPoint);
    final jeepDist = _geometry.polylineLengthMeters(segment);
    if (jeepDist < minJeepneyLegMeters) return null;

    final total = walkToBoardDist + jeepDist + walkFromAlightDist;
    if (!_passesDetourCheck(total, directMeters)) return null;

    // Penalize overshoot: if a named stop past destination would be used instead,
    // corridor projection should always be closer.
    final naiveAlight = _nearestStop(route, destination);
    if (naiveAlight != null) {
      final naiveDist = _geometry.distanceMeters(naiveAlight.latLng, destination);
      if (naiveDist > alightToDest + 80) {
        // Corridor projection is strictly better — good plan.
      }
    }

    final walkTo = await _geometry.safeWalkingRoute(origin, boardPoint);
    final walkFrom = await _geometry.safeWalkingRoute(alightPoint, destination);
    final jeepDuration = (jeepDist / jeepneySpeedMps).round();

    final travelFwd = boardProj.distanceFromStart < alightProj.distanceFromStart;
    final suffix = travelFwd ? 'fwd' : 'rev';
    final plan = JeepneyPlan(
      planId: 'jeep-${route.routeCode}-corridor-$suffix',
      boardRoute: route,
      boardStop: boardStop,
      alightStop: alightStop,
      boardPoint: boardPoint,
      alightPoint: alightPoint,
      walkToBoard: walkTo,
      walkFromAlight: walkFrom,
      jeepneyPolyline: segment,
      jeepneyDistanceMeters: jeepDist,
      jeepneyDurationSeconds: jeepDuration,
      estimatedTotalMeters:
          walkTo.distanceMeters + jeepDist + walkFrom.distanceMeters,
    );

    // Prefer shorter last-mile and fewer unnecessary legs.
    final score = total + jeepDist * 0.05 + walkFromAlightDist * 0.15;
    return (score: score, plan: plan);
  }

  RouteStop? _labelStop(JeepneyRoute route, LatLng point) {
    RouteStop? best;
    var bestDist = double.infinity;
    for (final stop in route.verifiedStops) {
      final d = _geometry.distanceMeters(point, stop.latLng);
      if (d < bestDist) {
        bestDist = d;
        best = stop;
      }
    }
    return best;
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
      final plan = await _tryOptimalSameRoute(
        route: route,
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

    final originPoly = originRoute.polyline.length >= 2
        ? originRoute.polyline
        : await _jeepneyPaths.roadPolylineForRoute(originRoute);
    final destPoly = destRoute.polyline.length >= 2
        ? destRoute.polyline
        : await _jeepneyPaths.roadPolylineForRoute(destRoute);
    final oPoly = originPoly.length >= 2 ? originPoly : originRoute.polyline;
    final dPoly = destPoly.length >= 2 ? destPoly : destRoute.polyline;

    final boardProj = _geometry.projectOntoPolyline(oPoly, origin);
    final alightProj = _geometry.projectOntoPolyline(dPoly, destination);
    final boardStop = _labelStop(originRoute, boardProj.point);
    final alightStop = _labelStop(destRoute, alightProj.point);
    if (boardStop == null || alightStop == null) return null;

    final firstLeg = _geometry.sliceBetweenPoints(
      oPoly,
      boardProj.point,
      transfer.originStop.latLng,
    );
    final secondLeg = _geometry.sliceBetweenPoints(
      dPoly,
      transfer.destStop.latLng,
      alightProj.point,
    );
    final firstDist = _geometry.polylineLengthMeters(firstLeg);
    final secondDist = _geometry.polylineLengthMeters(secondLeg);
    if (firstDist < minJeepneyLegMeters || secondDist < minJeepneyLegMeters) {
      return null;
    }

    final walkTo = await _geometry.safeWalkingRoute(origin, boardProj.point);
    final walkFrom =
        await _geometry.safeWalkingRoute(alightProj.point, destination);
    final transferWalk = await _geometry.safeWalkingRoute(
      transfer.originStop.latLng,
      transfer.destStop.latLng,
    );

    final total = walkTo.distanceMeters +
        firstDist +
        transfer.walkMeters +
        secondDist +
        walkFrom.distanceMeters;
    if (!_passesDetourCheck(total, directMeters)) return null;

    final plan = JeepneyPlan(
      planId:
          'xfer-${originRoute.routeCode}-${destRoute.routeCode}-corridor',
      boardRoute: originRoute,
      boardStop: boardStop,
      alightStop: alightStop,
      boardPoint: boardProj.point,
      alightPoint: alightProj.point,
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
    return (score: score, plan: plan);
  }
}
