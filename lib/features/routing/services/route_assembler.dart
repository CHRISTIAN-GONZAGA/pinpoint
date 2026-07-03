import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/fare_calculator.dart';
import 'package:pinpoint/features/routing/services/jeepney_plan.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';
import 'package:pinpoint/features/routing/services/tricycle_connector.dart';

/// Assembles [PlannedRoute] objects from jeepney plans and feeder legs.
class RouteAssembler {
  RouteAssembler({
    required RoutingGeometry geometry,
    required FareCalculator fares,
    required TricycleConnector tricycleConnector,
  })  : _geometry = geometry,
        _fares = fares,
        _tricycle = tricycleConnector;

  final RoutingGeometry _geometry;
  final FareCalculator _fares;
  final TricycleConnector _tricycle;

  static const walkMinMeters = 30.0;
  static const jeepneySpeedMps = 200 / 60;
  static const tricycleSpeedMps = 150 / 60;
  static const taxiSpeedMps = 250 / 60;
  static const walkOnlyMaxMeters = 1400.0;

  Future<PlannedRoute?> buildWalkRoute({
    required MapLocation origin,
    required MapLocation destination,
  }) async {
    final walk = await _geometry.safeWalkingRoute(origin.latLng, destination.latLng);
    if (walk.distanceMeters > walkOnlyMaxMeters) return null;

    return _finalize(
      optionId: 'walk',
      primaryMode: VehicleMode.walk,
      summaryTitle: 'Walk',
      steps: [
        RouteStep(
          type: RouteStepType.walk,
          instruction:
              'Walk ${walk.distanceMeters.round()} m to ${destination.label ?? "destination"}',
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
      walkingDistance: walk.distanceMeters,
      fare: 0,
      transferCount: 0,
      stopCount: 0,
    );
  }

  Future<PlannedRoute> buildTaxiRoute({
    required MapLocation origin,
    required MapLocation destination,
  }) async {
    final drive = await _geometry.safeDrivingRoute(
      origin.latLng,
      destination.latLng,
      speedMps: taxiSpeedMps,
    );
    final polyline =
        drive.polyline.isNotEmpty ? drive.polyline : [origin.latLng, destination.latLng];
    final fare = _fares.taxiFare(drive.distanceMeters);

    return _finalize(
      optionId: 'taxi',
      primaryMode: VehicleMode.taxi,
      summaryTitle: 'Taxi',
      steps: [
        RouteStep(
          type: RouteStepType.taxi,
          instruction: 'Take taxi door-to-door to ${destination.label ?? "destination"}',
          distanceMeters: drive.distanceMeters,
          durationSeconds: drive.durationSeconds > 0
              ? drive.durationSeconds
              : (drive.distanceMeters / taxiSpeedMps).round(),
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
      walkingDistance: 0,
      fare: fare,
      transferCount: 0,
      stopCount: 0,
    );
  }

  Future<PlannedRoute?> buildTricycleRoute({
    required MapLocation origin,
    required MapLocation destination,
    String? warningMessage,
  }) async {
    final drive = await _geometry.safeDrivingRoute(
      origin.latLng,
      destination.latLng,
      speedMps: tricycleSpeedMps,
    );
    final polyline =
        drive.polyline.isNotEmpty ? drive.polyline : [origin.latLng, destination.latLng];
    final fare = _fares.tricycleFare(drive.distanceMeters);

    return _finalize(
      optionId: 'tricycle',
      primaryMode: VehicleMode.tricycle,
      summaryTitle: 'Tricycle',
      warningMessage: warningMessage,
      steps: [
        RouteStep(
          type: RouteStepType.tricycle,
          instruction: warningMessage != null
              ? 'Tricycle (restricted) — ${destination.label ?? "destination"}'
              : 'Take tricycle to ${destination.label ?? "destination"}',
          distanceMeters: drive.distanceMeters,
          durationSeconds: drive.durationSeconds > 0
              ? drive.durationSeconds
              : (drive.distanceMeters / tricycleSpeedMps).round(),
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
      walkingDistance: 0,
      fare: fare,
      transferCount: 0,
      stopCount: 0,
    );
  }

  Future<PlannedRoute?> buildFromJeepneyPlan({
    required MapLocation origin,
    required MapLocation destination,
    required JeepneyPlan plan,
    required List<TricycleZone> zones,
    FeederLeg? originFeeder,
    bool allowOriginFeeder = true,
    bool allowDestFeeder = true,
  }) async {
    final steps = <RouteStep>[];
    var walkingDistance = 0.0;
    var fare = 0.0;
    var transferCount = plan.transferCount;
    var stopCount = 2;

    if (allowOriginFeeder && originFeeder != null) {
      _addTricycle(steps, originFeeder, 'Ride tricycle to ${originFeeder.toLabel}');
      fare += _fares.tricycleFare(
        originFeeder.route.distanceMeters,
        zoneBaseFare: originFeeder.zone.baseFare,
      );
    } else if (plan.walkToBoard.distanceMeters > walkMinMeters) {
      _addWalk(steps, plan.walkToBoard, 'Walk to ${plan.boardStop.name}');
      walkingDistance += plan.walkToBoard.distanceMeters;
    }

    if (!plan.hasTransfer) {
      _addJeepney(
        steps,
        route: plan.boardRoute,
        instruction:
            'Ride ${plan.boardRoute.routeCode} to ${plan.alightStop.name}',
        distanceMeters: plan.jeepneyDistanceMeters,
        durationSeconds: plan.jeepneyDurationSeconds,
        polyline: plan.jeepneyPolyline,
      );
      fare += _fares.jeepneyFare(plan.jeepneyDistanceMeters);
    } else {
      transferCount = 1;
      stopCount = 3;
      _addJeepney(
        steps,
        route: plan.boardRoute,
        instruction: 'Ride ${plan.boardRoute.routeCode} to ${plan.transferOriginStop!.name}',
        distanceMeters: plan.firstLegDistanceMeters,
        durationSeconds: plan.firstLegDurationSeconds,
        polyline: plan.firstLegPolyline,
      );
      fare += _fares.jeepneyFare(plan.firstLegDistanceMeters);

      steps.add(RouteStep(
        type: RouteStepType.transfer,
        instruction:
            'Transfer at ${plan.transferOriginStop!.name} → board ${plan.transferRoute!.routeCode}',
        distanceMeters: plan.transferWalkMeters,
        durationSeconds: math.max(120, (plan.transferWalkMeters / 1.2).round()),
        segmentColorHex: '#8338EC',
      ));

      if (plan.transferWalk != null && plan.transferWalk!.distanceMeters > walkMinMeters) {
        _addWalk(steps, plan.transferWalk!, 'Walk between jeepney stops');
        walkingDistance += plan.transferWalk!.distanceMeters;
      }

      _addJeepney(
        steps,
        route: plan.transferRoute!,
        instruction: 'Ride ${plan.transferRoute!.routeCode} to ${plan.alightStop.name}',
        distanceMeters: plan.secondLegDistanceMeters,
        durationSeconds: plan.secondLegDurationSeconds,
        polyline: plan.secondLegPolyline,
      );
      fare += _fares.jeepneyFare(plan.secondLegDistanceMeters);
    }

    FeederLeg? destFeeder;
    if (allowDestFeeder) {
      destFeeder = await _tricycle.destinationFeeder(
        alightStop: plan.alightStop,
        destination: destination.latLng,
        zones: zones,
      );
    }

    if (destFeeder != null) {
      _addTricycle(steps, destFeeder, 'Take tricycle in ${destFeeder.zone.zoneName}');
      fare += _fares.tricycleFare(
        destFeeder.route.distanceMeters,
        zoneBaseFare: destFeeder.zone.baseFare,
      );
    } else if (plan.walkFromAlight.distanceMeters > walkMinMeters) {
      _addWalk(steps, plan.walkFromAlight, 'Walk to destination');
      walkingDistance += plan.walkFromAlight.distanceMeters;
    }

    steps.add(const RouteStep(
      type: RouteStepType.walk,
      instruction: 'You have arrived',
      distanceMeters: 0,
      durationSeconds: 0,
    ));

    final optionId = originFeeder != null ? 'feeder-${plan.planId}' : plan.planId;
    final summary = _buildSummary(steps, plan);

    return _finalize(
      optionId: optionId,
      primaryMode: VehicleMode.jeepney,
      summaryTitle: summary,
      steps: steps,
      walkingDistance: walkingDistance,
      fare: fare,
      transferCount: transferCount,
      stopCount: stopCount,
    );
  }

  void _addWalk(
    List<RouteStep> steps,
    ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) route,
    String label,
  ) {
    steps.add(RouteStep(
      type: RouteStepType.walk,
      instruction: '$label (${route.distanceMeters.round()} m)',
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      polyline: route.polyline,
      segmentColorHex: '#64748B',
    ));
  }

  void _addJeepney(
    List<RouteStep> steps, {
    required JeepneyRoute route,
    required String instruction,
    required double distanceMeters,
    required int durationSeconds,
    required List<LatLng> polyline,
  }) {
    steps.add(RouteStep(
      type: RouteStepType.jeepney,
      instruction: instruction,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      routeCode: route.routeCode,
      polyline: polyline,
      segmentColorHex: route.colorHex,
    ));
  }

  void _addTricycle(List<RouteStep> steps, FeederLeg feeder, String instruction) {
    steps.add(RouteStep(
      type: RouteStepType.tricycle,
      instruction: instruction,
      distanceMeters: feeder.route.distanceMeters,
      durationSeconds: feeder.route.durationSeconds > 0
          ? feeder.route.durationSeconds
          : (feeder.route.distanceMeters / tricycleSpeedMps).round(),
      polyline: feeder.route.polyline.isNotEmpty
          ? feeder.route.polyline
          : [feeder.from, feeder.to],
      segmentColorHex: '#F59E0B',
    ));
  }

  String _buildSummary(List<RouteStep> steps, JeepneyPlan plan) {
    final parts = <String>[];
    for (final step in steps) {
      if (step.type == RouteStepType.walk && step.distanceMeters == 0) continue;
      parts.add(switch (step.type) {
        RouteStepType.walk => 'Walk',
        RouteStepType.jeepney => step.routeCode ?? 'Jeepney',
        RouteStepType.tricycle => 'Tricycle',
        RouteStepType.taxi => 'Taxi',
        RouteStepType.transfer => 'Transfer',
      });
    }
    return parts.join(' → ');
  }

  PlannedRoute _finalize({
    required String optionId,
    required VehicleMode primaryMode,
    required String summaryTitle,
    required List<RouteStep> steps,
    required double walkingDistance,
    required double fare,
    required int transferCount,
    required int stopCount,
    String? warningMessage,
  }) {
    final segments = <ColoredRouteSegment>[];
    final fullPolyline = <LatLng>[];
    var totalDistance = 0.0;
    var totalDuration = 0;

    for (final step in steps) {
      totalDistance += step.distanceMeters;
      totalDuration += step.durationSeconds;
      if (step.polyline.isNotEmpty) {
        fullPolyline.addAll(step.polyline);
        if (step.type != RouteStepType.transfer) {
          segments.add(ColoredRouteSegment(
            type: step.type,
            polyline: step.polyline,
            colorHex: step.segmentColorHex ?? '#64748B',
            routeCode: step.routeCode,
          ));
        }
      }
    }

    return PlannedRoute(
      optionId: optionId,
      steps: steps,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      estimatedFare: double.parse(fare.toStringAsFixed(2)),
      transferCount: transferCount,
      fullPolyline: fullPolyline,
      walkingDistanceMeters: walkingDistance,
      primaryMode: primaryMode,
      warningMessage: warningMessage,
      coloredSegments: segments,
      summaryTitle: summaryTitle,
      stopCount: stopCount,
    );
  }
}
