import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/widgets/route_summary_sheet.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';

PlannedRoute _sampleRoute({
  String? warning,
  String optionId = 'walk-1',
  bool isRecommended = false,
}) {
  return PlannedRoute(
    optionId: optionId,
    steps: const [
      RouteStep(
        type: RouteStepType.walk,
        instruction: 'Walk to destination',
        distanceMeters: 800,
        durationSeconds: 600,
      ),
    ],
    totalDistanceMeters: 800,
    totalDurationSeconds: 600,
    estimatedFare: 0,
    transferCount: 0,
    fullPolyline: const [LatLng(8.95, 125.54)],
    walkingDistanceMeters: 800,
    primaryMode: VehicleMode.walk,
    isRecommended: isRecommended,
    warningMessage: warning,
  );
}

void main() {
  testWidgets('shows unserved jeepney warning on route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 400,
            child: RouteSummarySheet(
              route: _sampleRoute(warning: unservedJeepneyMessage),
              routeOptions: [_sampleRoute(warning: unservedJeepneyMessage)],
              canGenerate: true,
              onClose: () {},
              onDismiss: () {},
              onGenerate: () {},
              onSelectOption: (_) {},
              onVehicleModeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(unservedJeepneyMessage), findsOneWidget);
  });

  testWidgets(
    'shows finding location and a settings action when location fails',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 400,
              child: RouteSummarySheet(
                route: null,
                routeOptions: const [],
                canGenerate: false,
                isLocating: true,
                originLabel: 'Start',
                destinationLabel: 'Robinsons',
                onClose: () {},
                onDismiss: () {},
                onGenerate: () {},
                onSelectOption: (_) {},
                onVehicleModeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Finding your location…'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 400,
              child: RouteSummarySheet(
                route: null,
                routeOptions: const [],
                canGenerate: false,
                locationWarning: 'Location permission denied.',
                originLabel: 'Start',
                destinationLabel: 'Robinsons',
                onOpenLocationSettings: () {},
                onClose: () {},
                onDismiss: () {},
                onGenerate: () {},
                onSelectOption: (_) {},
                onVehicleModeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Location permission denied.'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    },
  );

  testWidgets('shows every route option in ranked order', (tester) async {
    final recommended = _sampleRoute(optionId: 'best', isRecommended: true);
    final alternative = _sampleRoute(optionId: 'alternative');
    PlannedRoute? selectedOption;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 400,
            child: RouteSummarySheet(
              route: recommended,
              routeOptions: [recommended, alternative],
              canGenerate: true,
              onClose: () {},
              onDismiss: () {},
              onGenerate: () {},
              onSelectOption: (option) => selectedOption = option,
              onVehicleModeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All route options'), findsOneWidget);
    expect(
      find.text('Tap an option to show its color-coded route on the map'),
      findsOneWidget,
    );
    expect(find.text('2 options'), findsOneWidget);
    expect(find.text('OPTION 1  ·  10 min'), findsOneWidget);
    expect(find.text('OPTION 2  ·  10 min'), findsOneWidget);

    await tester.ensureVisible(find.text('OPTION 2  ·  10 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPTION 2  ·  10 min'));
    expect(selectedOption?.optionId, 'alternative');
  });

  testWidgets('shows route-specific PUJ colors and blue tricycle labels', (
    tester,
  ) async {
    final route = PlannedRoute(
      optionId: 'mixed-r1',
      steps: const [
        RouteStep(
          type: RouteStepType.jeepney,
          instruction: 'Ride R1',
          distanceMeters: 1200,
          durationSeconds: 360,
          routeCode: 'R1',
          routeName: 'West and East Loop',
          segmentColorHex: '#1D3557',
        ),
        RouteStep(
          type: RouteStepType.tricycle,
          instruction: 'Take a tricycle',
          distanceMeters: 500,
          durationSeconds: 180,
          segmentColorHex: '#0EA5E9',
        ),
      ],
      totalDistanceMeters: 1700,
      totalDurationSeconds: 540,
      estimatedFare: 25,
      transferCount: 0,
      fullPolyline: const [LatLng(8.95, 125.54)],
      walkingDistanceMeters: 0,
      primaryMode: VehicleMode.jeepney,
      isRecommended: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 400,
            child: RouteSummarySheet(
              route: route,
              routeOptions: [route],
              canGenerate: true,
              onClose: () {},
              onDismiss: () {},
              onGenerate: () {},
              onSelectOption: (_) {},
              onVehicleModeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PUJ route colors'), findsOneWidget);
    expect(find.text('R1'), findsWidgets);
    expect(find.text('Tricycle'), findsOneWidget);
  });
}
