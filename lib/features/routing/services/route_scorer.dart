import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';

/// Scores route candidates using configurable weights.
class RouteScorer {
  const RouteScorer();

  static const longWalkThresholdMeters = 450.0;

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
    final hasTricycleFeeder = route.steps.any((s) => s.type == RouteStepType.tricycle);

    if (route.primaryMode == VehicleMode.taxi) {
      total += weights.taxiPenalty;
    }

    if (hasJeepney) {
      final jeepIdx = route.steps.indexWhere((s) => s.type == RouteStepType.jeepney);
      final triAfterJeepney = route.steps
          .sublist(jeepIdx + 1)
          .any((s) => s.type == RouteStepType.tricycle && s.distanceMeters > 30);
      if (triAfterJeepney) total += 40;
    }

    if (route.primaryMode == VehicleMode.tricycle && !hasJeepney) {
      total += weights.tricyclePenalty;
      if (route.warningMessage != null) total += 25;
    }

    if (hasJeepney) {
      total -= weights.jeepneyBonus;
      if (route.transferCount > 0) total -= 8;

      // Tricycle → PUJ is the practical Butuan pattern for last-mile access.
      if (hasTricycleFeeder) total -= 22;

      // Penalize long walks to/from PUJ when a tricycle feeder exists in the candidate set.
      if (route.walkingDistanceMeters > longWalkThresholdMeters && !hasTricycleFeeder) {
        total += 35;
      }
    }

    if (route.primaryMode == VehicleMode.walk &&
        route.walkingDistanceMeters < 800 &&
        route.coloredSegments.every((s) => s.type == RouteStepType.walk)) {
      total -= 12;
    }

    return total;
  }
}
