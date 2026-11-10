import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/routing/services/route_ranker.dart';

PlannedRoute _route({
  required String id,
  required VehicleMode mode,
  double fare = 20,
  int duration = 600,
  double walk = 200,
  int transfers = 0,
  List<RouteStep>? steps,
}) {
  return PlannedRoute(
    steps: steps ??
        [
          RouteStep(
            type: switch (mode) {
              VehicleMode.tricycle => RouteStepType.tricycle,
              VehicleMode.taxi => RouteStepType.taxi,
              VehicleMode.walk => RouteStepType.walk,
              _ => RouteStepType.jeepney,
            },
            instruction: 'Ride',
            distanceMeters: 1000,
            durationSeconds: duration,
            polyline: const [LatLng(8.95, 125.54)],
          ),
        ],
    totalDistanceMeters: 1000,
    totalDurationSeconds: duration,
    estimatedFare: fare,
    transferCount: transfers,
    fullPolyline: const [LatLng(8.95, 125.54)],
    walkingDistanceMeters: walk,
    optionId: id,
    primaryMode: mode,
  );
}

void main() {
  const ranker = RouteRanker();

  test('cheapest preference recommends lowest fare option', () {
    final ranked = ranker.rank(
      candidates: [
        _route(id: 'jeep', mode: VehicleMode.jeepney, fare: 26),
        _route(id: 'walk', mode: VehicleMode.walk, fare: 0, duration: 1200, walk: 800),
        _route(id: 'taxi', mode: VehicleMode.taxi, fare: 120, duration: 300),
      ],
      preference: RoutePreference.cheapest,
    );

    expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'walk');
  });

  test('fastest preference recommends shortest duration', () {
    final ranked = ranker.rank(
      candidates: [
        _route(id: 'jeep', mode: VehicleMode.jeepney, fare: 26, duration: 900),
        _route(id: 'taxi', mode: VehicleMode.taxi, fare: 120, duration: 400),
      ],
      preference: RoutePreference.fastest,
    );

    expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'taxi');
  });

  test('retains all generated route alternatives beyond the old display cap', () {
    final candidates = List.generate(
      10,
      (index) => _route(
        id: 'route-$index',
        mode: VehicleMode.jeepney,
        steps: [
          RouteStep(
            type: RouteStepType.jeepney,
            instruction: 'Ride route $index',
            routeCode: 'R$index',
            distanceMeters: 1000,
            durationSeconds: 600 + index,
            polyline: const [LatLng(8.95, 125.54)],
          ),
        ],
      ),
    );

    final ranked = ranker.rank(
      candidates: candidates,
      preference: RoutePreference.balanced,
    );

    expect(ranked, hasLength(candidates.length));
    expect(
      ranked.map((route) => route.optionId),
      containsAll(candidates.map((route) => route.optionId)),
    );
  });

  test('balanced preference prefers jeepney over taxi when viable', () {
    final ranked = ranker.rank(
      candidates: [
        _route(id: 'jeep', mode: VehicleMode.jeepney, fare: 26, duration: 900),
        _route(id: 'taxi', mode: VehicleMode.taxi, fare: 120, duration: 400),
      ],
      preference: RoutePreference.balanced,
    );

    expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'jeep');
  });

  test('balanced prefers tricycle feeder when walk to PUJ is long', () {
    final directJeep = _route(
      id: 'direct',
      mode: VehicleMode.jeepney,
      walk: 800,
    );
    final feederJeep = _route(
      id: 'feeder',
      mode: VehicleMode.jeepney,
      walk: 120,
      steps: const [
        RouteStep(
          type: RouteStepType.tricycle,
          instruction: 'Tricycle to stop',
          distanceMeters: 500,
          durationSeconds: 180,
          polyline: [LatLng(8.95, 125.54)],
        ),
        RouteStep(
          type: RouteStepType.jeepney,
          instruction: 'Ride R7',
          distanceMeters: 2000,
          durationSeconds: 600,
          polyline: [LatLng(8.96, 125.55)],
        ),
      ],
    );

    final ranked = ranker.rank(
      candidates: [directJeep, feederJeep],
      preference: RoutePreference.balanced,
    );

    expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'feeder');
    expect(
      ranked.firstWhere((r) => r.isRecommended).explanation,
      contains('Butuan'),
    );
  });

  test(
    'balanced prefers an accessible jeepney over a similar short tricycle trip',
    () {
      final ranked = ranker.rank(
        candidates: [
          _route(
            id: 'trike',
            mode: VehicleMode.tricycle,
            fare: 24,
            duration: 680,
          ),
          _route(
            id: 'jeep',
            mode: VehicleMode.jeepney,
            fare: 28,
            duration: 720,
            walk: 250,
          ),
        ],
        preference: RoutePreference.balanced,
      );

      expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'jeep');
      expect(ranked.map((r) => r.optionId), containsAll(['trike', 'jeep']));
    },
  );

  test(
    'balanced prefers direct tricycle when jeepney access requires a long walk',
    () {
      final ranked = ranker.rank(
        candidates: [
          _route(
            id: 'trike',
            mode: VehicleMode.tricycle,
            fare: 18,
            duration: 480,
          ),
          _route(
            id: 'jeep',
            mode: VehicleMode.jeepney,
            fare: 28,
            duration: 720,
            walk: 650,
          ),
        ],
        preference: RoutePreference.balanced,
      );

      expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'trike');
      expect(ranked.map((r) => r.optionId), containsAll(['trike', 'jeep']));
    },
  );

  test('vehicle mode filter overrides preference recommendation', () {
    final ranked = ranker.rank(
      candidates: [
        _route(id: 'jeep', mode: VehicleMode.jeepney, fare: 26),
        _route(id: 'taxi', mode: VehicleMode.taxi, fare: 120),
      ],
      preference: RoutePreference.cheapest,
      preferredMode: VehicleMode.taxi,
    );

    expect(ranked.firstWhere((r) => r.isRecommended).optionId, 'taxi');
  });
}
