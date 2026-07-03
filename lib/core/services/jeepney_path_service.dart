import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Builds road-following jeepney paths by chaining OSRM driving legs between stops.
class JeepneyPathService {
  JeepneyPathService({RoutingService? routingService})
      : _routing = routingService ?? RoutingService();

  final RoutingService _routing;
  final Map<int, List<LatLng>> _cache = {};

  /// Returns a polyline that follows drivable roads between jeepney stops.
  Future<List<LatLng>> roadPolylineForRoute(JeepneyRoute route) async {
    final cached = _cache[route.routeId];
    if (cached != null && cached.isNotEmpty) return cached;

    if (route.verifiedStops.length >= 2) {
      final points = <LatLng>[];
      final stops = route.verifiedStops;
      for (var i = 0; i < stops.length - 1; i++) {
        final from = stops[i].latLng;
        final to = stops[i + 1].latLng;
        final leg = await _roadLeg(from, to);
        if (points.isEmpty) {
          points.addAll(leg);
        } else if (leg.isNotEmpty) {
          points.addAll(leg.skip(1));
        }
      }
      if (points.length >= 2) {
        _cache[route.routeId] = points;
        return points;
      }
    }

    if (route.polyline.length >= 2) {
      final points = <LatLng>[];
      for (var i = 0; i < route.polyline.length - 1; i++) {
        final leg = await _roadLeg(route.polyline[i], route.polyline[i + 1]);
        if (points.isEmpty) {
          points.addAll(leg);
        } else if (leg.isNotEmpty) {
          points.addAll(leg.skip(1));
        }
      }
      if (points.length >= 2) {
        _cache[route.routeId] = points;
        return points;
      }
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
