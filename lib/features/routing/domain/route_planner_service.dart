import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Plans multi-modal journeys with jeepney, tricycle, and taxi options.
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
  final Distance _distance = const Distance();

  static const _walkMinMeters = 30.0;
  static const _maxWalkToStopMeters = 900.0;
  static const _walkOnlyMaxMeters = 1400.0;
  static const _maxDetourRatio = 2.4;
  static const _tricycleLastMileMeters = 400.0;
  static const _jeepneySpeedMps = 200 / 60; // ~12 km/h
  static const _tricycleSpeedMps = 150 / 60; // ~9 km/h
  static const _taxiSpeedMps = 250 / 60; // ~15 km/h in city

  /// Plans all viable routes and marks the recommended option.
  Future<List<PlannedRoute>> planRouteOptions({
    required MapLocation origin,
    required MapLocation destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required List<TricycleZone> tricycleZones,
    required List<FareConfig> fares,
    VehicleMode preferredMode = VehicleMode.auto,
  }) async {
    final highway = _highway ?? await HighwayRestrictionService.load();
    final fareMap = _fareMap(fares);

    final options = <PlannedRoute>[];

    final walkOnly = await _planWalkOnlyRoute(origin: origin, destination: destination);
    if (walkOnly != null) options.add(walkOnly);

    final jeepney = await _planJeepneyRoute(
      origin: origin,
      destination: destination,
      jeepneyRoutes: jeepneyRoutes,
      tricycleZones: tricycleZones,
      jeepneyFare: fareMap['jeepney']!,
      tricycleFare: fareMap['tricycle']!,
    );
    if (jeepney != null) options.add(jeepney);

    final tricycle = await _planTricycleRoute(
      origin: origin,
      destination: destination,
      tricycleFare: fareMap['tricycle']!,
      highway: highway,
    );
    if (tricycle != null) options.add(tricycle);

    final taxi = await _planTaxiRoute(
      origin: origin,
      destination: destination,
      taxiFare: fareMap['taxi']!,
    );
    options.add(taxi);

    if (options.isEmpty) {
      throw Exception('No route could be planned for this trip.');
    }

    _markRecommended(options);

    if (preferredMode != VehicleMode.auto) {
      final match = options.where((o) => o.primaryMode == preferredMode).toList();
      if (match.isNotEmpty) {
        return [
          match.first.copyWith(isRecommended: true),
          ...options.where((o) => o.primaryMode != preferredMode),
        ];
      }
    }

    options.sort((a, b) {
      if (a.isRecommended != b.isRecommended) return a.isRecommended ? -1 : 1;
      return a.totalDurationSeconds.compareTo(b.totalDurationSeconds);
    });
    return options;
  }

  /// Backward-compatible single-route entry (auto mode, best option).
  Future<PlannedRoute> planRoute({
    required MapLocation origin,
    required MapLocation destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required List<TricycleZone> tricycleZones,
    required List<FareConfig> fares,
    VehicleMode mode = VehicleMode.auto,
  }) async {
    final options = await planRouteOptions(
      origin: origin,
      destination: destination,
      jeepneyRoutes: jeepneyRoutes,
      tricycleZones: tricycleZones,
      fares: fares,
      preferredMode: mode,
    );
    return options.first;
  }

  Map<String, FareConfig> _fareMap(List<FareConfig> fares) {
    FareConfig find(String type, double min, double rate) => fares.firstWhere(
          (f) => f.transportType == type,
          orElse: () => FareConfig(
            transportType: type,
            minimumFare: min,
            succeedingRate: rate,
          ),
        );
    return {
      'jeepney': find('jeepney', 13, 1.8),
      'tricycle': find('tricycle', 15, 2),
      'taxi': find('taxi', 40, 13.5),
    };
  }

  void _markRecommended(List<PlannedRoute> options) {
    if (options.isEmpty) return;
    final directMeters = options
        .map((o) => o.totalDistanceMeters)
        .reduce((a, b) => a < b ? a : b);

    var bestIdx = 0;
    var bestScore = double.infinity;
    for (var i = 0; i < options.length; i++) {
      final route = options[i];
      if (route.warningMessage != null && route.primaryMode == VehicleMode.tricycle) {
        continue;
      }

      // Penalise routes that are much longer than the shortest option (detours).
      final detourPenalty = route.totalDistanceMeters > directMeters * 1.6
          ? (route.totalDistanceMeters / directMeters) * 8
          : 0.0;

      final walkBonus = route.walkingDistanceMeters > 0 &&
              route.coloredSegments.every((s) => s.type == RouteStepType.walk)
          ? (route.totalDistanceMeters < 1500 ? -25.0 : -6.0)
          : 0.0;

      final transferPenalty = route.transferCount * 5.0;

      final score = route.estimatedFare * 0.5 +
          (route.totalDurationSeconds / 60) * 3.5 +
          detourPenalty +
          transferPenalty +
          walkBonus;

      if (score < bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    options[bestIdx] = options[bestIdx].copyWith(isRecommended: true);
  }

  Future<PlannedRoute?> _planWalkOnlyRoute({
    required MapLocation origin,
    required MapLocation destination,
  }) async {
    final walk = await _safeWalkingRoute(origin.latLng, destination.latLng);
    if (walk.distanceMeters > _walkOnlyMaxMeters) return null;

    final segments = [
      ColoredRouteSegment(
        type: RouteStepType.walk,
        polyline: walk.polyline,
        colorHex: '#64748B',
      ),
    ];

    return PlannedRoute(
      steps: [
        RouteStep(
          type: RouteStepType.walk,
          instruction: 'Walk ${walk.distanceMeters.round()} m to ${destination.label ?? "destination"}',
          distanceMeters: walk.distanceMeters,
          durationSeconds: walk.durationSeconds,
          polyline: walk.polyline,
          segmentColorHex: '#64748B',
        ),
        const RouteStep(
          type: RouteStepType.walk,
          instruction: 'You have arrived',
          distanceMeters: 0,
          durationSeconds: 0,
        ),
      ],
      totalDistanceMeters: walk.distanceMeters,
      totalDurationSeconds: walk.durationSeconds,
      estimatedFare: 0,
      transferCount: 0,
      fullPolyline: walk.polyline,
      walkingDistanceMeters: walk.distanceMeters,
      primaryMode: VehicleMode.auto,
      coloredSegments: segments,
    );
  }

  Future<PlannedRoute?> _planJeepneyRoute({
    required MapLocation origin,
    required MapLocation destination,
    required List<JeepneyRoute> jeepneyRoutes,
    required List<TricycleZone> tricycleZones,
    required FareConfig jeepneyFare,
    required FareConfig tricycleFare,
  }) async {
    if (jeepneyRoutes.isEmpty) return null;

    final originPoint = origin.latLng;
    final destPoint = destination.latLng;
    final directMeters = _routing.distanceMeters(originPoint, destPoint);

    final plan = await _findBestJeepneyPlan(
      origin: originPoint,
      destination: destPoint,
      jeepneyRoutes: jeepneyRoutes,
    );
    if (plan == null) return null;

    if (plan.estimatedTotalMeters > directMeters * _maxDetourRatio &&
        directMeters < 2500) {
      return null;
    }

    final steps = <RouteStep>[];
    final segments = <ColoredRouteSegment>[];
    final fullPolyline = <LatLng>[];
    var totalDistance = 0.0;
    var totalDuration = 0;
    var walkingDistance = 0.0;
    var estimatedFare = 0.0;
    var transferCount = 0;

    void addWalk(RouteStep step) {
      steps.add(step);
      if (step.polyline.isNotEmpty) {
        fullPolyline.addAll(step.polyline);
        segments.add(ColoredRouteSegment(
          type: RouteStepType.walk,
          polyline: step.polyline,
          colorHex: '#64748B',
        ));
      }
      totalDistance += step.distanceMeters;
      totalDuration += step.durationSeconds;
      walkingDistance += step.distanceMeters;
    }

    void addJeepney(RouteStep step) {
      steps.add(step);
      if (step.polyline.isNotEmpty) {
        fullPolyline.addAll(step.polyline);
        segments.add(ColoredRouteSegment(
          type: RouteStepType.jeepney,
          polyline: step.polyline,
          colorHex: step.segmentColorHex ?? '#1A3A6B',
          routeCode: step.routeCode,
        ));
      }
      totalDistance += step.distanceMeters;
      totalDuration += step.durationSeconds;
      estimatedFare += jeepneyFare.computeFare(step.distanceMeters / 1000);
    }

    if (plan.walkToBoard.distanceMeters > _walkMinMeters) {
      addWalk(RouteStep(
        type: RouteStepType.walk,
        instruction:
            'Walk ${plan.walkToBoard.distanceMeters.round()} m to ${plan.boardStop.name}',
        distanceMeters: plan.walkToBoard.distanceMeters,
        durationSeconds: plan.walkToBoard.durationSeconds,
        polyline: plan.walkToBoard.polyline,
        segmentColorHex: '#64748B',
      ));
    }

    if (plan.transferRoute == null) {
      addJeepney(RouteStep(
        type: RouteStepType.jeepney,
        instruction:
            'Ride ${plan.boardRoute.routeCode} (${plan.boardRoute.routeName}) to ${plan.alightStop.name}',
        distanceMeters: plan.jeepneyDistanceMeters,
        durationSeconds: plan.jeepneyDurationSeconds,
        routeCode: plan.boardRoute.routeCode,
        polyline: plan.jeepneyPolyline,
        segmentColorHex: plan.boardRoute.colorHex,
      ));
    } else {
      transferCount = 1;
      addJeepney(RouteStep(
        type: RouteStepType.jeepney,
        instruction: 'Ride ${plan.boardRoute.routeCode} to ${plan.transferOriginStop!.name}',
        distanceMeters: plan.firstLegDistanceMeters,
        durationSeconds: plan.firstLegDurationSeconds,
        routeCode: plan.boardRoute.routeCode,
        polyline: plan.firstLegPolyline,
        segmentColorHex: plan.boardRoute.colorHex,
      ));

      steps.add(RouteStep(
        type: RouteStepType.transfer,
        instruction:
            'Transfer at ${plan.transferOriginStop!.name} → board ${plan.transferRoute!.routeCode}',
        distanceMeters: plan.transferWalkMeters,
        durationSeconds: math.max(120, (plan.transferWalkMeters / 1.2).round()),
        segmentColorHex: '#8338EC',
      ));
      totalDuration += steps.last.durationSeconds;

      if (plan.transferWalk != null && plan.transferWalk!.distanceMeters > _walkMinMeters) {
        addWalk(RouteStep(
          type: RouteStepType.walk,
          instruction: 'Walk ${plan.transferWalk!.distanceMeters.round()} m between jeepney stops',
          distanceMeters: plan.transferWalk!.distanceMeters,
          durationSeconds: plan.transferWalk!.durationSeconds,
          polyline: plan.transferWalk!.polyline,
          segmentColorHex: '#64748B',
        ));
      }

      addJeepney(RouteStep(
        type: RouteStepType.jeepney,
        instruction: 'Ride ${plan.transferRoute!.routeCode} to ${plan.alightStop.name}',
        distanceMeters: plan.secondLegDistanceMeters,
        durationSeconds: plan.secondLegDurationSeconds,
        routeCode: plan.transferRoute!.routeCode,
        polyline: plan.secondLegPolyline,
        segmentColorHex: plan.transferRoute!.colorHex,
      ));
    }

    final destZone = _findZone(destPoint, tricycleZones);
    final lastMile = _routing.distanceMeters(plan.alightStop.latLng, destPoint);
    if (destZone != null && lastMile > _tricycleLastMileMeters) {
      final triRoute = await _safeDrivingRoute(plan.alightStop.latLng, destPoint);
      final triPolyline =
          triRoute.polyline.isNotEmpty ? triRoute.polyline : [plan.alightStop.latLng, destPoint];
      steps.add(RouteStep(
        type: RouteStepType.tricycle,
        instruction: 'Take tricycle in ${destZone.zoneName} to destination',
        distanceMeters: triRoute.distanceMeters,
        durationSeconds: triRoute.durationSeconds > 0
            ? triRoute.durationSeconds
            : (triRoute.distanceMeters / _tricycleSpeedMps).round(),
        polyline: triPolyline,
        segmentColorHex: '#F59E0B',
      ));
      fullPolyline.addAll(triPolyline);
      segments.add(ColoredRouteSegment(
        type: RouteStepType.tricycle,
        polyline: triPolyline,
        colorHex: '#F59E0B',
      ));
      totalDistance += triRoute.distanceMeters;
      totalDuration += steps.last.durationSeconds;
      estimatedFare += math.max(destZone.baseFare, tricycleFare.minimumFare);
    } else if (lastMile > _walkMinMeters) {
      final walkFromStop = await _safeWalkingRoute(plan.alightStop.latLng, destPoint);
      addWalk(RouteStep(
        type: RouteStepType.walk,
        instruction: 'Walk ${walkFromStop.distanceMeters.round()} m to destination',
        distanceMeters: walkFromStop.distanceMeters,
        durationSeconds: walkFromStop.durationSeconds,
        polyline: walkFromStop.polyline,
        segmentColorHex: '#64748B',
      ));
    }

    steps.add(const RouteStep(
      type: RouteStepType.walk,
      instruction: 'You have arrived',
      distanceMeters: 0,
      durationSeconds: 0,
    ));

    return PlannedRoute(
      steps: steps,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      estimatedFare: double.parse(estimatedFare.toStringAsFixed(2)),
      transferCount: transferCount,
      fullPolyline: fullPolyline,
      walkingDistanceMeters: walkingDistance,
      primaryMode: VehicleMode.jeepney,
      coloredSegments: segments,
    );
  }

  Future<_JeepneyPlan?> _findBestJeepneyPlan({
    required LatLng origin,
    required LatLng destination,
    required List<JeepneyRoute> jeepneyRoutes,
  }) async {
    _JeepneyPlan? best;
    var bestScore = double.infinity;
    final directMeters = _routing.distanceMeters(origin, destination);

    for (final route in jeepneyRoutes) {
      final sameRoute = await _scoreSameRoutePlan(
        route: route,
        origin: origin,
        destination: destination,
        directMeters: directMeters,
      );
      if (sameRoute != null && sameRoute.score < bestScore) {
        bestScore = sameRoute.score;
        best = sameRoute.plan;
      }
    }

    for (var i = 0; i < jeepneyRoutes.length; i++) {
      for (var j = 0; j < jeepneyRoutes.length; j++) {
        if (i == j) continue;
        final transfer = await _scoreTransferPlan(
          originRoute: jeepneyRoutes[i],
          destRoute: jeepneyRoutes[j],
          origin: origin,
          destination: destination,
          directMeters: directMeters,
        );
        if (transfer != null && transfer.score < bestScore) {
          bestScore = transfer.score;
          best = transfer.plan;
        }
      }
    }

    return best;
  }

  Future<({double score, _JeepneyPlan plan})?> _scoreSameRoutePlan({
    required JeepneyRoute route,
    required LatLng origin,
    required LatLng destination,
    required double directMeters,
  }) async {
    final roadPoly = await _jeepneyPaths.roadPolylineForRoute(route);
    if (roadPoly.length < 2) return null;

    RouteStop? bestBoard;
    RouteStop? bestAlight;
    List<LatLng>? bestSegment;
    var bestTotal = double.infinity;

    for (final board in route.stops) {
      final walkToBoard = _routing.distanceMeters(origin, board.latLng);
      if (walkToBoard > _maxWalkToStopMeters) continue;

      for (final alight in route.stops) {
        if (board.stopId == alight.stopId) continue;
        if (board.order >= alight.order) continue;

        final walkFromAlight = _routing.distanceMeters(alight.latLng, destination);
        if (walkFromAlight > _maxWalkToStopMeters) continue;

        final segment = _sliceBetweenPoints(roadPoly, board.latLng, alight.latLng);
        final jeepDist = _polylineLengthMeters(segment);
        if (jeepDist < 80) continue;

        final total = walkToBoard + jeepDist + walkFromAlight;
        if (total > directMeters * _maxDetourRatio && directMeters < 3000) continue;
        if (directMeters <= _walkOnlyMaxMeters && total > directMeters * 1.35) continue;

        if (total < bestTotal) {
          bestTotal = total;
          bestBoard = board;
          bestAlight = alight;
          bestSegment = segment;
        }
      }
    }

    if (bestBoard == null || bestAlight == null || bestSegment == null) return null;

    final walkTo = await _safeWalkingRoute(origin, bestBoard.latLng);
    final walkFrom = await _safeWalkingRoute(bestAlight.latLng, destination);
    final jeepDist = _polylineLengthMeters(bestSegment);
    final jeepDuration = (jeepDist / _jeepneySpeedMps).round();

    final plan = _JeepneyPlan(
      boardRoute: route,
      boardStop: bestBoard,
      alightStop: bestAlight,
      walkToBoard: walkTo,
      jeepneyPolyline: bestSegment,
      jeepneyDistanceMeters: jeepDist,
      jeepneyDurationSeconds: jeepDuration,
      estimatedTotalMeters: walkTo.distanceMeters + jeepDist + walkFrom.distanceMeters,
    );

    final score = plan.estimatedTotalMeters + jeepDist * 0.15;
    return (score: score, plan: plan);
  }

  Future<({double score, _JeepneyPlan plan})?> _scoreTransferPlan({
    required JeepneyRoute originRoute,
    required JeepneyRoute destRoute,
    required LatLng origin,
    required LatLng destination,
    required double directMeters,
  }) async {
    final transfer = _findBestTransfer(originRoute, destRoute);
    if (transfer.walkMeters > 600) return null;

    final boardStop = _nearestStopOnRoute(originRoute, origin, maxMeters: _maxWalkToStopMeters);
    final alightStop =
        _nearestStopOnRoute(destRoute, destination, maxMeters: _maxWalkToStopMeters);
    if (boardStop == null || alightStop == null) return null;
    if (boardStop.order >= transfer.originStop.order) return null;
    if (transfer.destStop.order >= alightStop.order) return null;

    final originPoly = await _jeepneyPaths.roadPolylineForRoute(originRoute);
    final destPoly = await _jeepneyPaths.roadPolylineForRoute(destRoute);

    final firstLeg = _sliceBetweenPoints(originPoly, boardStop.latLng, transfer.originStop.latLng);
    final secondLeg = _sliceBetweenPoints(destPoly, transfer.destStop.latLng, alightStop.latLng);
    final firstDist = _polylineLengthMeters(firstLeg);
    final secondDist = _polylineLengthMeters(secondLeg);

    final walkTo = await _safeWalkingRoute(origin, boardStop.latLng);
    final walkFrom = await _safeWalkingRoute(alightStop.latLng, destination);
    final transferWalk = await _safeWalkingRoute(transfer.originStop.latLng, transfer.destStop.latLng);

    final total = walkTo.distanceMeters +
        firstDist +
        transfer.walkMeters +
        secondDist +
        walkFrom.distanceMeters;
    if (total > directMeters * (_maxDetourRatio + 0.3)) return null;

    final plan = _JeepneyPlan(
      boardRoute: originRoute,
      boardStop: boardStop,
      alightStop: alightStop,
      walkToBoard: walkTo,
      transferRoute: destRoute,
      transferOriginStop: transfer.originStop,
      transferDestStop: transfer.destStop,
      transferWalk: transferWalk,
      transferWalkMeters: transfer.walkMeters,
      firstLegPolyline: firstLeg,
      firstLegDistanceMeters: firstDist,
      firstLegDurationSeconds: (firstDist / _jeepneySpeedMps).round(),
      secondLegPolyline: secondLeg,
      secondLegDistanceMeters: secondDist,
      secondLegDurationSeconds: (secondDist / _jeepneySpeedMps).round(),
      estimatedTotalMeters: total,
    );

    return (score: total + 200, plan: plan);
  }

  List<LatLng> _sliceBetweenPoints(List<LatLng> polyline, LatLng from, LatLng to) {
    if (polyline.isEmpty) return [from, to];
    final fromIdx = _nearestPolylineIndex(polyline, from);
    final toIdx = _nearestPolylineIndex(polyline, to);
    if (fromIdx == toIdx) return [polyline[fromIdx]];
    if (fromIdx < toIdx) return List<LatLng>.from(polyline.sublist(fromIdx, toIdx + 1));
    return List<LatLng>.from(polyline.sublist(toIdx, fromIdx + 1).reversed);
  }

  int _nearestPolylineIndex(List<LatLng> polyline, LatLng point) {
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < polyline.length; i++) {
      final d = _distance.as(LengthUnit.Meter, point, polyline[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  double _polylineLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += _routing.distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }

  RouteStop? _nearestStopOnRoute(JeepneyRoute route, LatLng point, {required double maxMeters}) {
    RouteStop? best;
    var bestDist = double.infinity;
    for (final stop in route.stops) {
      final d = _distance.as(LengthUnit.Meter, point, stop.latLng);
      if (d < bestDist && d <= maxMeters) {
        bestDist = d;
        best = stop;
      }
    }
    return best;
  }

  Future<PlannedRoute?> _planTricycleRoute({
    required MapLocation origin,
    required MapLocation destination,
    required FareConfig tricycleFare,
    required HighwayRestrictionService highway,
  }) async {
    final drive = await _safeDrivingRoute(origin.latLng, destination.latLng);
    final polyline = drive.polyline.isNotEmpty
        ? drive.polyline
        : [origin.latLng, destination.latLng];

    String? warning;
    if (highway.pathUsesNationalHighway(polyline)) {
      warning =
          'Direct tricycle route crosses a national highway. Tricycles must use barangay roads only — consider Jeepney or Taxi.';
    }

    final fare = tricycleFare.computeFare(drive.distanceMeters / 1000);
    final segments = [
      ColoredRouteSegment(
        type: RouteStepType.tricycle,
        polyline: polyline,
        colorHex: '#F59E0B',
      ),
    ];

    return PlannedRoute(
      steps: [
        RouteStep(
          type: RouteStepType.tricycle,
          instruction: warning != null
              ? 'Tricycle (restricted) — ${destination.label ?? "destination"}'
              : 'Take tricycle to ${destination.label ?? "destination"}',
          distanceMeters: drive.distanceMeters,
          durationSeconds: drive.durationSeconds > 0
              ? drive.durationSeconds
              : (drive.distanceMeters / _tricycleSpeedMps).round(),
          polyline: polyline,
          segmentColorHex: '#F59E0B',
        ),
        const RouteStep(
          type: RouteStepType.walk,
          instruction: 'You have arrived',
          distanceMeters: 0,
          durationSeconds: 0,
        ),
      ],
      totalDistanceMeters: drive.distanceMeters,
      totalDurationSeconds: drive.durationSeconds > 0
          ? drive.durationSeconds
          : (drive.distanceMeters / _tricycleSpeedMps).round(),
      estimatedFare: double.parse(fare.toStringAsFixed(2)),
      transferCount: 0,
      fullPolyline: polyline,
      walkingDistanceMeters: 0,
      primaryMode: VehicleMode.tricycle,
      warningMessage: warning,
      coloredSegments: segments,
    );
  }

  Future<PlannedRoute> _planTaxiRoute({
    required MapLocation origin,
    required MapLocation destination,
    required FareConfig taxiFare,
  }) async {
    final drive = await _safeDrivingRoute(origin.latLng, destination.latLng);
    final polyline = drive.polyline.isNotEmpty
        ? drive.polyline
        : [origin.latLng, destination.latLng];
    final fare = taxiFare.computeFare(drive.distanceMeters / 1000);

    final segments = [
      ColoredRouteSegment(
        type: RouteStepType.taxi,
        polyline: polyline,
        colorHex: '#EAB308',
      ),
    ];

    return PlannedRoute(
      steps: [
        RouteStep(
          type: RouteStepType.taxi,
          instruction: 'Take taxi door-to-door to ${destination.label ?? "destination"}',
          distanceMeters: drive.distanceMeters,
          durationSeconds: drive.durationSeconds > 0
              ? drive.durationSeconds
              : (drive.distanceMeters / _taxiSpeedMps).round(),
          polyline: polyline,
          segmentColorHex: '#EAB308',
        ),
        const RouteStep(
          type: RouteStepType.walk,
          instruction: 'You have arrived',
          distanceMeters: 0,
          durationSeconds: 0,
        ),
      ],
      totalDistanceMeters: drive.distanceMeters,
      totalDurationSeconds: drive.durationSeconds > 0
          ? drive.durationSeconds
          : (drive.distanceMeters / _taxiSpeedMps).round(),
      estimatedFare: double.parse(fare.toStringAsFixed(2)),
      transferCount: 0,
      fullPolyline: polyline,
      walkingDistanceMeters: 0,
      primaryMode: VehicleMode.taxi,
      coloredSegments: segments,
    );
  }

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      _safeWalkingRoute(LatLng from, LatLng to) async {
    try {
      return await _routing.getWalkingRoute(from, to);
    } catch (_) {
      final dist = _routing.distanceMeters(from, to);
      return (
        polyline: [from, to],
        distanceMeters: dist,
        durationSeconds: (dist / 1.2).round(),
      );
    }
  }

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      _safeDrivingRoute(LatLng from, LatLng to) async {
    try {
      return await _routing.getDrivingRoute(from, to);
    } catch (_) {
      final dist = _routing.distanceMeters(from, to);
      return (
        polyline: [from, to],
        distanceMeters: dist,
        durationSeconds: (dist / _taxiSpeedMps).round(),
      );
    }
  }

  ({RouteStop originStop, RouteStop destStop, LatLng transferPoint, double walkMeters})
      _findBestTransfer(JeepneyRoute originRoute, JeepneyRoute destRoute) {
    RouteStop? bestOrigin;
    RouteStop? bestDest;
    var bestWalk = double.infinity;

    for (final oStop in originRoute.stops) {
      for (final dStop in destRoute.stops) {
        final walk = _routing.distanceMeters(oStop.latLng, dStop.latLng);
        if (walk < bestWalk) {
          bestWalk = walk;
          bestOrigin = oStop;
          bestDest = dStop;
        }
      }
    }

    bestOrigin ??= originRoute.stops.last;
    bestDest ??= destRoute.stops.first;
    final mid = LatLng(
      (bestOrigin.latitude + bestDest.latitude) / 2,
      (bestOrigin.longitude + bestDest.longitude) / 2,
    );
    return (
      originStop: bestOrigin,
      destStop: bestDest,
      transferPoint: mid,
      walkMeters: bestWalk,
    );
  }

  TricycleZone? _findZone(LatLng point, List<TricycleZone> zones) {
    for (final zone in zones) {
      if (_pointInPolygon(point, zone.polygon)) return zone;
    }
    return null;
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi + 0.0000001) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

class _JeepneyPlan {
  const _JeepneyPlan({
    required this.boardRoute,
    required this.boardStop,
    required this.alightStop,
    required this.walkToBoard,
    required this.estimatedTotalMeters,
    this.jeepneyPolyline = const [],
    this.jeepneyDistanceMeters = 0,
    this.jeepneyDurationSeconds = 0,
    this.transferRoute,
    this.transferOriginStop,
    this.transferDestStop,
    this.transferWalk,
    this.transferWalkMeters = 0,
    this.firstLegPolyline = const [],
    this.firstLegDistanceMeters = 0,
    this.firstLegDurationSeconds = 0,
    this.secondLegPolyline = const [],
    this.secondLegDistanceMeters = 0,
    this.secondLegDurationSeconds = 0,
  });

  final JeepneyRoute boardRoute;
  final RouteStop boardStop;
  final RouteStop alightStop;
  final ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) walkToBoard;
  final double estimatedTotalMeters;

  final List<LatLng> jeepneyPolyline;
  final double jeepneyDistanceMeters;
  final int jeepneyDurationSeconds;

  final JeepneyRoute? transferRoute;
  final RouteStop? transferOriginStop;
  final RouteStop? transferDestStop;
  final ({List<LatLng> polyline, double distanceMeters, int durationSeconds})? transferWalk;
  final double transferWalkMeters;

  final List<LatLng> firstLegPolyline;
  final double firstLegDistanceMeters;
  final int firstLegDurationSeconds;
  final List<LatLng> secondLegPolyline;
  final double secondLegDistanceMeters;
  final int secondLegDurationSeconds;
}

extension on PlannedRoute {
  PlannedRoute copyWith({
    bool? isRecommended,
    String? warningMessage,
  }) {
    return PlannedRoute(
      steps: steps,
      totalDistanceMeters: totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds,
      estimatedFare: estimatedFare,
      transferCount: transferCount,
      fullPolyline: fullPolyline,
      walkingDistanceMeters: walkingDistanceMeters,
      primaryMode: primaryMode,
      isRecommended: isRecommended ?? this.isRecommended,
      warningMessage: warningMessage ?? this.warningMessage,
      coloredSegments: coloredSegments,
    );
  }
}
