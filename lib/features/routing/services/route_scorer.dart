import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';

/// Scores route candidates using configurable weights.
class RouteScorer {
  const RouteScorer();

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

    if (route.primaryMode == VehicleMode.taxi) {
      total += weights.taxiPenalty;
    }

    if (route.warningMessage != null && route.primaryMode == VehicleMode.tricycle) {
      total += 50;
    }

    // Prefer public transport multimodal over single-mode taxi for balanced scoring.
    if (route.primaryMode == VehicleMode.jeepney && weights.taxiPenalty > 0) {
      total -= 8;
    }

    if (route.primaryMode == VehicleMode.walk &&
        route.walkingDistanceMeters < 800 &&
        route.coloredSegments.every((s) => s.type == RouteStepType.walk)) {
      total -= 8;
    }

    return total;
  }
}
