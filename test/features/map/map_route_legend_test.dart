import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_route_legend.dart';

void main() {
  testWidgets('identifies the colored jeepney route by code and route name', (
    tester,
  ) async {
    final route = PlannedRoute(
      optionId: 'jeep-r1',
      steps: const [
        RouteStep(
          type: RouteStepType.jeepney,
          instruction: 'Ride R1',
          distanceMeters: 1200,
          durationSeconds: 360,
          routeCode: 'R1',
          routeName: 'West and East Loop',
          segmentColorHex: '#E63946',
        ),
      ],
      totalDistanceMeters: 1200,
      totalDurationSeconds: 360,
      estimatedFare: 13,
      transferCount: 0,
      fullPolyline: const [LatLng(8.95, 125.54)],
      walkingDistanceMeters: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MapRouteLegend(route: route)),
      ),
    );

    expect(find.text('R1 · West and East Loop'), findsOneWidget);
  });
}
