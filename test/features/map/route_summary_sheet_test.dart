import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/widgets/route_summary_sheet.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';

PlannedRoute _sampleRoute({String? warning}) {
  return PlannedRoute(
    optionId: 'walk-1',
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

  testWidgets('shows finding location and a settings action when location fails', (tester) async {
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
  });
}
