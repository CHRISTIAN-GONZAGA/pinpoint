import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';

/// Scores route candidates using configurable weights.
class RouteScorer {
  const RouteScorer();

  static const longWalkThresholdMeters = 450.0;
  static const shortTricycleBoostMeters = 4000.0;

  double score(
    PlannedRoute route,
    ScoringWeights weights, {
    required double maxWalking,
    required double maxDuration,
    required double maxFare,
    required int maxTransfers,
  }) {
    final walkNorm = maxWalking > 0 ? route.walkingDistanceMeters / maxWalking : 0;
    final timeNorm = maxDuration > 0 ? route.totalDurationSeconds / maxDuration : 0;
    final fareNorm = maxFare > 0 ? route.estimatedFare / maxFare : 0;
    final transferNorm = maxTransfers > 0 ? route.transferCount / maxTransfers : 0;

    var total = walkNorm * weights.walkingDistance * 100 +
        timeNorm * weights.travelTime * 100 +
        fareNorm * weights.fare * 100 +
        transferNorm * weights.transfers * 100;

    final hasJeepney = route.steps.any((s) => s.type == RouteStepType.jeepney);
    final hasTricycleFeeder = route.steps.any((s) => s.type == RouteStepType.tricycle) &&
        hasJeepney &&
        route.steps.indexWhere((s) => s.type == RouteStepType.tricycle) <
            route.steps.indexWhere((s) => s.type == RouteStepType.jeepney);

    if (route.primaryMode == VehicleMode.taxi) {
      total += weights.taxiPenalty;
    }

    if (hasJeepney) {
      final jeepIdx = route.steps.indexWhere((s) => s.type == RouteStepType.jeepney);
      final triAfterJeepney = route.steps
          .sublist(jeepIdx + 1)
          .any((s) => s.type == RouteStepType.tricycle && s.distanceMeters > 30);
      if (triAfterJeepney) total += 45;

      // Jeepney without tricycle feeder but long walk to board — impractical in Butuan.
      if (!hasTricycleFeeder && route.walkingDistanceMeters > longWalkThresholdMeters) {
        total += 55;
      }
    }

    if (route.primaryMode == VehicleMode.tricycle && !hasJeepney) {
      if (route.totalDistanceMeters <= shortTricycleBoostMeters) {
        total -= 28;
      } else {
        total += weights.tricyclePenalty;
      }
      if (route.warningMessage != null) total += 25;
    }

    if (hasJeepney) {
      total -= weights.jeepneyBonus;

      if (hasTricycleFeeder) total -= 25;

      if (route.transferCount > 0) {
        total += 30 * route.transferCount;
      }

      final jeepneyMeters = route.steps
          .where((s) => s.type == RouteStepType.jeepney)
          .fold<double>(0, (sum, s) => sum + s.distanceMeters);
      if (jeepneyMeters < 600 && !hasTricycleFeeder) {
        total += 35;
      }
    }

    if (route.primaryMode == VehicleMode.walk &&
        route.walkingDistanceMeters < 800 &&
        route.coloredSegments.every((s) => s.type == RouteStepType.walk)) {
      total -= 15;
    }

    return total;
  }
}
