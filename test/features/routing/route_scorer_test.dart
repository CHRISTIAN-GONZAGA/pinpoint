import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/route_scorer.dart';

void main() {
  const scorer = RouteScorer();

  PlannedRoute sample({
    required String id,
    required VehicleMode mode,
    double walk = 200,
    int duration = 600,
    double fare = 15,
    int transfers = 0,
  }) {
    return PlannedRoute(
      optionId: id,
      steps: const [],
      totalDistanceMeters: 1000,
      totalDurationSeconds: duration,
      estimatedFare: fare,
      transferCount: transfers,
      fullPolyline: const [LatLng(8.95, 125.54)],
      walkingDistanceMeters: walk,
      primaryMode: mode,
    );
  }

  test('balanced scoring penalizes taxi over jeepney', () {
    final weights = ScoringWeights.forPreference(RoutePreference.balanced);
    final jeepney = sample(id: 'jeep', mode: VehicleMode.jeepney);
    final taxi = sample(id: 'taxi', mode: VehicleMode.taxi, fare: 40, duration: 180);

    final jeepScore = scorer.score(
      jeepney,
      weights,
      maxWalking: 500,
      maxDuration: 1200,
      maxFare: 50,
      maxTransfers: 2,
    );
    final taxiScore = scorer.score(
      taxi,
      weights,
      maxWalking: 500,
      maxDuration: 1200,
      maxFare: 50,
      maxTransfers: 2,
    );

    expect(jeepScore, lessThan(taxiScore));
  });
}
