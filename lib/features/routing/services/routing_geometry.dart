import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';

/// Shared polyline and distance helpers for the routing engine.
class RoutingGeometry {
  RoutingGeometry(this._routing);

  final RoutingService _routing;
  final Distance _distance = const Distance();

  double distanceMeters(LatLng a, LatLng b) => _routing.distanceMeters(a, b);

  double polylineLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += _routing.distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }

  List<LatLng> sliceBetweenPoints(List<LatLng> polyline, LatLng from, LatLng to) {
    if (polyline.isEmpty) return [from, to];
    final fromIdx = nearestPolylineIndex(polyline, from);
    final toIdx = nearestPolylineIndex(polyline, to);
    if (fromIdx == toIdx) return [polyline[fromIdx]];
    if (fromIdx < toIdx) return List<LatLng>.from(polyline.sublist(fromIdx, toIdx + 1));
    return List<LatLng>.from(polyline.sublist(toIdx, fromIdx + 1).reversed);
  }

  int nearestPolylineIndex(List<LatLng> polyline, LatLng point) {
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < polyline.length; i++) {
      final d = _distance.as(LengthUnit.Meter, point, polyline[i]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  double distancePointToPolylineMeters(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return _distance.as(LengthUnit.Meter, point, polyline.first);
    }
    var best = double.infinity;
    for (var i = 0; i < polyline.length; i++) {
      final d = _distance.as(LengthUnit.Meter, point, polyline[i]);
      if (d < best) best = d;
    }
    return best;
  }

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      safeWalkingRoute(LatLng from, LatLng to) async {
    try {
      return await _routing.getWalkingRoute(from, to);
    } catch (_) {
      final dist = _routing.distanceMeters(from, to);
      return (
        polyline: [from, to],
        distanceMeters: dist,
        durationSeconds: (dist / 1.2).round(),
      );
    }
  }

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      safeDrivingRoute(LatLng from, LatLng to, {double speedMps = 250 / 60}) async {
    try {
      return await _routing.getDrivingRoute(from, to);
    } catch (_) {
      final dist = _routing.distanceMeters(from, to);
      return (
        polyline: [from, to],
        distanceMeters: dist,
        durationSeconds: (dist / speedMps).round(),
      );
    }
  }
}
