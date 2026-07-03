import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/route_pdf_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

void main() {
  test('RoutePdfService generates non-empty PDF bytes', () async {
    final route = PlannedRoute(
      optionId: 'test-walk',
      steps: const [
        RouteStep(
          type: RouteStepType.walk,
          instruction: 'Walk to jeepney stop',
          distanceMeters: 200,
          durationSeconds: 180,
        ),
      ],
      totalDistanceMeters: 1200,
      totalDurationSeconds: 900,
      estimatedFare: 15,
      transferCount: 0,
      fullPolyline: [const LatLng(8.95, 125.54)],
      walkingDistanceMeters: 200,
    );

    final bytes = await RoutePdfService().generate(
      route: route,
      originLabel: 'Baan Junction',
      destinationLabel: 'Robinsons',
    );

    expect(bytes.isNotEmpty, isTrue);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
