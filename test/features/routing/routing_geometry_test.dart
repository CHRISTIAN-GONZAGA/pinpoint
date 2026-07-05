import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

void main() {
  final geometry = RoutingGeometry(RoutingService(offlineMode: true));

  // Simplified north→south corridor (like R7 through city proper).
  final corridor = [
    const LatLng(8.960, 125.530),
    const LatLng(8.955, 125.532),
    const LatLng(8.950, 125.534),
    const LatLng(8.945, 125.536),
    const LatLng(8.940, 125.538),
  ];

  test('projects destination onto corridor without overshooting south', () {
    final origin = const LatLng(8.958, 125.528);
    final destination = const LatLng(8.948, 125.535);

    final board = geometry.projectOntoPolyline(corridor, origin);
    final alight = geometry.projectOntoPolyline(corridor, destination);

    expect(board.distanceFromStart, lessThan(alight.distanceFromStart));

    final segment = geometry.sliceBetweenPoints(corridor, board.point, alight.point);
    expect(segment.length, greaterThan(1));

    final endToDest = geometry.distanceMeters(segment.last, destination);
    expect(endToDest, lessThan(200));
  });

  test('alight projection is closer to destination than terminal stop', () {
    final destination = const LatLng(8.948, 125.535);
    const capitol = LatLng(8.940, 125.538);

    final destProj = geometry.projectOntoPolyline(corridor, destination);
    final capToDest = geometry.distanceMeters(capitol, destination);
    final projToDest = geometry.distanceMeters(destProj.point, destination);

    expect(projToDest, lessThan(capToDest));
  });
}
