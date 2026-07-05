import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/services/routing_service.dart';

/// A point projected onto a route polyline with its arc-length position.
class PolylineProjection {
  const PolylineProjection({
    required this.point,
    required this.segmentIndex,
    required this.distanceFromQuery,
    required this.distanceFromStart,
  });

  final LatLng point;
  final int segmentIndex;
  final double distanceFromQuery;
  /// Meters from the start of the polyline along the corridor.
  final double distanceFromStart;
}

/// Shared polyline and distance helpers for the routing engine.
class RoutingGeometry {
  RoutingGeometry(this._routing);

  final RoutingService _routing;
  final Distance _distance = const Distance();

  static const shortLegMeters = 90.0;

  double distanceMeters(LatLng a, LatLng b) => _routing.distanceMeters(a, b);

  double polylineLengthMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += _routing.distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }

  /// Projects [query] onto the nearest segment of [polyline].
  PolylineProjection projectOntoPolyline(List<LatLng> polyline, LatLng query) {
    if (polyline.isEmpty) {
      return PolylineProjection(
        point: query,
        segmentIndex: 0,
        distanceFromQuery: double.infinity,
        distanceFromStart: 0,
      );
    }
    if (polyline.length == 1) {
      final d = distanceMeters(query, polyline.first);
      return PolylineProjection(
        point: polyline.first,
        segmentIndex: 0,
        distanceFromQuery: d,
        distanceFromStart: 0,
      );
    }

    var bestPoint = polyline.first;
    var bestDist = double.infinity;
    var bestSeg = 0;
    var bestAlongSeg = 0.0;
    var cumLen = 0.0;

    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final segLen = distanceMeters(a, b);
      final proj = _projectOnSegment(query, a, b);
      final d = distanceMeters(query, proj.point);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = proj.point;
        bestSeg = i;
        bestAlongSeg = proj.t * segLen;
      }
      cumLen += segLen;
    }

    // Recompute distanceFromStart for the winning segment.
    var fromStart = 0.0;
    for (var i = 0; i < bestSeg; i++) {
      fromStart += distanceMeters(polyline[i], polyline[i + 1]);
    }
    fromStart += bestAlongSeg;

    return PolylineProjection(
      point: bestPoint,
      segmentIndex: bestSeg,
      distanceFromQuery: bestDist,
      distanceFromStart: fromStart,
    );
  }

  List<LatLng> sliceBetweenPoints(List<LatLng> polyline, LatLng from, LatLng to) {
    if (polyline.isEmpty) return [from, to];
    if (polyline.length == 1) return [from, to];

    final fromProj = projectOntoPolyline(polyline, from);
    final toProj = projectOntoPolyline(polyline, to);

    if ((fromProj.distanceFromStart - toProj.distanceFromStart).abs() < 5) {
      return [fromProj.point, toProj.point];
    }

    if (fromProj.distanceFromStart <= toProj.distanceFromStart) {
      return _sliceForward(polyline, fromProj, toProj);
    }
    return _sliceForward(polyline, toProj, fromProj).reversed.toList();
  }

  List<LatLng> _sliceForward(
    List<LatLng> polyline,
    PolylineProjection start,
    PolylineProjection end,
  ) {
    final result = <LatLng>[start.point];
    for (var i = start.segmentIndex + 1; i <= end.segmentIndex; i++) {
      if (i < polyline.length) result.add(polyline[i]);
    }
    if (distanceMeters(result.last, end.point) > 3) {
      result.add(end.point);
    }
    return result;
  }

  int nearestPolylineIndex(List<LatLng> polyline, LatLng point) {
    return projectOntoPolyline(polyline, point).segmentIndex;
  }

  double distancePointToPolylineMeters(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    return projectOntoPolyline(polyline, point).distanceFromQuery;
  }

  ({LatLng point, double t}) _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    final latScale = math.cos(a.latitude * math.pi / 180);
    final ax = a.longitude * latScale;
    final ay = a.latitude;
    final bx = b.longitude * latScale;
    final by = b.latitude;
    final px = p.longitude * latScale;
    final py = p.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq < 1e-12) return (point: a, t: 0);

    var t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    return (
      point: LatLng(
        ay + t * dy,
        (ax + t * dx) / latScale,
      ),
      t: t,
    );
  }

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      safeWalkingRoute(LatLng from, LatLng to) async {
    final straight = _routing.distanceMeters(from, to);
    if (straight <= shortLegMeters) {
      return (
        polyline: [from, to],
        distanceMeters: straight,
        durationSeconds: (straight / 1.2).round().clamp(30, 99999),
      );
    }
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
    final straight = _routing.distanceMeters(from, to);
    if (straight <= shortLegMeters) {
      return (
        polyline: [from, to],
        distanceMeters: straight,
        durationSeconds: (straight / speedMps).round().clamp(30, 99999),
      );
    }
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
