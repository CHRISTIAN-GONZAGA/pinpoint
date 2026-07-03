import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/highway_restriction_service.dart';

void main() {
  final service = HighwayRestrictionService(
    corridors: [
      [
        const LatLng(8.944, 125.528),
        const LatLng(8.952, 125.548),
        const LatLng(8.960, 125.568),
      ],
    ],
    bufferMeters: 80,
  );

  test('detects path crossing national highway corridor', () {
    final path = [
      const LatLng(8.943, 125.527),
      const LatLng(8.951, 125.547),
      const LatLng(8.959, 125.567),
    ];
    expect(service.pathUsesNationalHighway(path), isTrue);
  });

  test('allows barangay-only path away from highway', () {
    final path = [
      const LatLng(8.930, 125.510),
      const LatLng(8.932, 125.515),
      const LatLng(8.935, 125.518),
    ];
    expect(service.pathUsesNationalHighway(path), isFalse);
  });
}
