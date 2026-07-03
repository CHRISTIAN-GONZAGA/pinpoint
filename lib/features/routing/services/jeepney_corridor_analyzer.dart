import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

/// Identifies which jeepney corridors (R1–R7) serve a location.
class JeepneyCorridorAnalyzer {
  JeepneyCorridorAnalyzer(this._geometry);

  final RoutingGeometry _geometry;

  static const corridorThresholdMeters = 450.0;

  /// Routes whose polyline or stops are within [corridorThresholdMeters] of [point].
  List<({JeepneyRoute route, double distanceMeters})> corridorsNear(
    LatLng point,
    List<JeepneyRoute> routes,
  ) {
    final results = <({JeepneyRoute route, double distanceMeters})>[];
    for (final route in routes) {
      var nearest = double.infinity;
      for (final stop in route.stops) {
        final d = _geometry.distanceMeters(point, stop.latLng);
        if (d < nearest) nearest = d;
      }
      for (final p in route.polyline) {
        final d = _geometry.distanceMeters(point, p);
        if (d < nearest) nearest = d;
      }
      if (nearest <= corridorThresholdMeters) {
        results.add((route: route, distanceMeters: nearest));
      }
    }
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  bool isNearCorridor(LatLng point, List<JeepneyRoute> routes) =>
      corridorsNear(point, routes).isNotEmpty;
}
