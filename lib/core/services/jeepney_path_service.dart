import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Builds road-following jeepney paths by chaining OSRM driving legs between stops.
class JeepneyPathService {
  JeepneyPathService({RoutingService? routingService})
      : _routing = routingService ?? RoutingService();

  final RoutingService _routing;
  final Map<int, List<LatLng>> _cache = {};

  /// Returns the route corridor polyline for planning and map display.
  ///
  /// Uses bundled [JeepneyRoute.polyline] from LPTRP data. OSRM corridor
  /// refinement is done offline at build time — not during trip planning.
  Future<List<LatLng>> roadPolylineForRoute(JeepneyRoute route) async {
    final cached = _cache[route.routeId];
    if (cached != null && cached.isNotEmpty) return cached;

    if (route.polyline.length >= 2) {
      _cache[route.routeId] = route.polyline;
      return route.polyline;
    }

    if (route.verifiedStops.length >= 2) {
      final points = route.verifiedStops.map((s) => s.latLng).toList();
      _cache[route.routeId] = points;
      return points;
    }

    _cache[route.routeId] = route.polyline;
    return route.polyline;
  }

  Future<List<LatLng>> _roadLeg(LatLng from, LatLng to) async {
    try {
      final result = await _routing.getDrivingRoute(from, to);
      if (result.polyline.length >= 2) return result.polyline;
    } catch (_) {}
    return [from, to];
  }

  Future<List<LatLng>> roadLeg(LatLng from, LatLng to) => _roadLeg(from, to);
}
