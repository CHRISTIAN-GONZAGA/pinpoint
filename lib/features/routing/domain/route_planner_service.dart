import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/highway_restriction_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Plans multi-modal journeys with jeepney, tricycle, and taxi options.
class RoutePlannerService {
  RoutePlannerService({
    RoutingService? routingService,
    HighwayRestrictionService? highwayService,
  })  : _routing = routingService ?? RoutingService(),
        _highway = highwayService;

  final RoutingService _routing;
  final HighwayRestrictionService? _highway;
  final Distance _distance = const Distance();

  static const _walkMinMeters = 30.0;
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
    var bestIdx = 0;
    var bestScore = double.infinity;
    for (var i = 0; i < options.length; i++) {
      final route = options[i];
      if (route.warningMessage != null && route.primaryMode == VehicleMode.tricycle) {
        continue;
      }
      // Balance fare (PHP) and time (minutes) — weight time slightly more.
      final score = route.estimatedFare * 0.6 + (route.totalDurationSeconds / 60) * 4;
      if (score < bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    options[bestIdx] = options[bestIdx].copyWith(isRecommended: true);
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
    final originMatch = _findNearestStop(originPoint, jeepneyRoutes);
    final destMatch = _findNearestStop(destPoint, jeepneyRoutes);

    final steps = <RouteStep>[];
    final segments = <ColoredRouteSegment>[];
    final fullPolyline = <LatLng>[];
    var totalDistance = 0.0;
    var totalDuration = 0;
    var transferCount = 0;
    var walkingDistance = 0.0;
    var estimatedFare = 0.0;

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

    if (originMatch == null || destMatch == null) {
      return null;
    }

    final (originRoute, originStop) = originMatch;
    final (destRoute, destStop) = destMatch;

    final walkToStop = await _safeWalkingRoute(originPoint, originStop.latLng);
    if (walkToStop.distanceMeters > _walkMinMeters) {
      addWalk(RouteStep(
        type: RouteStepType.walk,
        instruction: 'Walk ${walkToStop.distanceMeters.round()} m to ${originStop.name}',
        distanceMeters: walkToStop.distanceMeters,
        durationSeconds: walkToStop.durationSeconds,
        polyline: walkToStop.polyline,
        segmentColorHex: '#64748B',
      ));
    }

    if (originRoute.routeId == destRoute.routeId) {
      final jeepneyDistance = _routing.distanceMeters(originStop.latLng, destStop.latLng);
      final jeepneyPolyline = _segmentPolyline(
        originRoute.polyline,
        originStop.latLng,
        destStop.latLng,
      );
      addJeepney(RouteStep(
        type: RouteStepType.jeepney,
        instruction: 'Ride ${originRoute.routeCode} (${originRoute.routeName}) to ${destStop.name}',
        distanceMeters: jeepneyDistance,
        durationSeconds: (jeepneyDistance / _jeepneySpeedMps).round(),
        routeCode: originRoute.routeCode,
        polyline: jeepneyPolyline,
        segmentColorHex: originRoute.colorHex,
      ));
    } else {
      final transfer = _findBestTransfer(originRoute, destRoute);
      transferCount = 1;

      final firstLeg = _routing.distanceMeters(originStop.latLng, transfer.transferPoint);
      addJeepney(RouteStep(
        type: RouteStepType.jeepney,
        instruction: 'Ride ${originRoute.routeCode} to ${transfer.originStop.name}',
        distanceMeters: firstLeg,
        durationSeconds: (firstLeg / _jeepneySpeedMps).round(),
        routeCode: originRoute.routeCode,
        polyline: _segmentPolyline(
          originRoute.polyline,
          originStop.latLng,
          transfer.transferPoint,
        ),
        segmentColorHex: originRoute.colorHex,
      ));

      steps.add(RouteStep(
        type: RouteStepType.transfer,
        instruction:
            'Transfer at ${transfer.originStop.name} → board ${destRoute.routeCode}',
        distanceMeters: transfer.walkMeters,
        durationSeconds: math.max(120, (transfer.walkMeters / 1.2).round()),
        segmentColorHex: '#8338EC',
      ));
      totalDuration += steps.last.durationSeconds;

      if (transfer.walkMeters > _walkMinMeters) {
        final transferWalk = await _safeWalkingRoute(
          transfer.originStop.latLng,
          transfer.destStop.latLng,
        );
        addWalk(RouteStep(
          type: RouteStepType.walk,
          instruction: 'Walk ${transfer.walkMeters.round()} m between jeepney stops',
          distanceMeters: transferWalk.distanceMeters,
          durationSeconds: transferWalk.durationSeconds,
          polyline: transferWalk.polyline,
          segmentColorHex: '#64748B',
        ));
      }

      final secondLeg = _routing.distanceMeters(transfer.destStop.latLng, destStop.latLng);
      addJeepney(RouteStep(
        type: RouteStepType.jeepney,
        instruction: 'Ride ${destRoute.routeCode} to ${destStop.name}',
        distanceMeters: secondLeg,
        durationSeconds: (secondLeg / _jeepneySpeedMps).round(),
        routeCode: destRoute.routeCode,
        polyline: _segmentPolyline(
          destRoute.polyline,
          transfer.destStop.latLng,
          destStop.latLng,
        ),
        segmentColorHex: destRoute.colorHex,
      ));
    }

    final destZone = _findZone(destPoint, tricycleZones);
    final lastMile = _routing.distanceMeters(destStop.latLng, destPoint);
    if (destZone != null && lastMile > _tricycleLastMileMeters) {
      final triRoute = await _safeDrivingRoute(destStop.latLng, destPoint);
      final triPolyline = triRoute.polyline.isNotEmpty ? triRoute.polyline : [destStop.latLng, destPoint];
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
      final walkFromStop = await _safeWalkingRoute(destStop.latLng, destPoint);
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

  (JeepneyRoute, RouteStop)? _findNearestStop(LatLng point, List<JeepneyRoute> routes) {
    JeepneyRoute? bestRoute;
    RouteStop? bestStop;
    var bestDistance = double.infinity;
    for (final route in routes) {
      for (final stop in route.stops) {
        final d = _distance.as(LengthUnit.Meter, point, stop.latLng);
        if (d < bestDistance) {
          bestDistance = d;
          bestRoute = route;
          bestStop = stop;
        }
      }
    }
    if (bestRoute == null || bestStop == null) return null;
    return (bestRoute, bestStop);
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

  List<LatLng> _segmentPolyline(List<LatLng> routePolyline, LatLng from, LatLng to) {
    if (routePolyline.length < 2) return [from, to];
    var startIdx = 0;
    var endIdx = routePolyline.length - 1;
    var minStart = double.infinity;
    var minEnd = double.infinity;
    for (var i = 0; i < routePolyline.length; i++) {
      final ds = _distance.as(LengthUnit.Meter, from, routePolyline[i]);
      final de = _distance.as(LengthUnit.Meter, to, routePolyline[i]);
      if (ds < minStart) {
        minStart = ds;
        startIdx = i;
      }
      if (de < minEnd) {
        minEnd = de;
        endIdx = i;
      }
    }
    if (startIdx <= endIdx) {
      return [from, ...routePolyline.sublist(startIdx, endIdx + 1), to];
    }
    return [from, ...routePolyline.sublist(endIdx, startIdx + 1).reversed, to];
  }

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
