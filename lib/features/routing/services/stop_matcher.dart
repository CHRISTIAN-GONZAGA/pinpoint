import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

/// Evaluates nearby jeepney stops — includes corridor-based matching.
class StopMatcher {
  StopMatcher(this._geometry);

  final RoutingGeometry _geometry;

  /// Max walking distance to board/alight at a stop.
  static const maxWalkToStopMeters = 1800.0;

  /// If within this distance of the route polyline, all stops on the route are considered.
  static const corridorAttachMeters = 900.0;

  static const maxCandidates = 8;

  /// Returns stops on [route] near [point], ranked by walking distance.
  List<RouteStop> nearbyStopsOnRoute(
    JeepneyRoute route,
    LatLng point, {
    double maxMeters = maxWalkToStopMeters,
    int limit = maxCandidates,
  }) {
    final activeStops = route.verifiedStops;
    if (activeStops.isEmpty) return [];

    final corridorDist = _geometry.distancePointToPolylineMeters(point, route.polyline);

    final candidates = <({RouteStop stop, double dist})>[];
    for (final stop in activeStops) {
      final d = _geometry.distanceMeters(point, stop.latLng);
      final effectiveMax = corridorDist <= corridorAttachMeters
          ? maxMeters + corridorAttachMeters
          : maxMeters;
      if (d <= effectiveMax) candidates.add((stop: stop, dist: d));
    }

    if (candidates.isEmpty && corridorDist <= corridorAttachMeters && activeStops.isNotEmpty) {
      for (final stop in activeStops) {
        candidates.add((
          stop: stop,
          dist: _geometry.distanceMeters(point, stop.latLng),
        ));
      }
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

  /// Routes whose corridor or stops are reachable from [point].
  List<JeepneyRoute> routesServing(
    LatLng point,
    List<JeepneyRoute> routes, {
    double maxMeters = maxWalkToStopMeters,
  }) {
    final serving = <JeepneyRoute>[];
    for (final route in routes) {
      if (nearbyStopsOnRoute(route, point, maxMeters: maxMeters).isNotEmpty) {
        serving.add(route);
      }
    }
    return serving;
  }
}
