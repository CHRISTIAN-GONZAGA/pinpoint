import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

/// Evaluates nearby jeepney stops — not just the single nearest one.
class StopMatcher {
  StopMatcher(this._geometry);

  final RoutingGeometry _geometry;

  static const maxWalkToStopMeters = 900.0;
  static const maxCandidates = 6;

  /// Returns stops on [route] near [point], ranked by walking distance.
  List<RouteStop> nearbyStopsOnRoute(
    JeepneyRoute route,
    LatLng point, {
    double maxMeters = maxWalkToStopMeters,
    int limit = maxCandidates,
  }) {
    final candidates = <({RouteStop stop, double dist})>[];
    for (final stop in route.stops) {
      final d = _geometry.distanceMeters(point, stop.latLng);
      if (d <= maxMeters) candidates.add((stop: stop, dist: d));
    }
    candidates.sort((a, b) => a.dist.compareTo(b.dist));
    return candidates.take(limit).map((c) => c.stop).toList();
  }

  RouteStop? nearestStopOnRoute(
    JeepneyRoute route,
    LatLng point, {
    double maxMeters = maxWalkToStopMeters,
  }) {
    final nearby = nearbyStopsOnRoute(route, point, maxMeters: maxMeters, limit: 1);
    return nearby.isEmpty ? null : nearby.first;
  }
}
