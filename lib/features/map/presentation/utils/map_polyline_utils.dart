import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Helpers for route direction cues on the map.
abstract final class MapPolylineUtils {
  static const _distance = Distance();

  /// Places small chevron markers along a polyline to show travel direction.
  static List<Marker> directionMarkers(
    List<LatLng> points, {
    required Color color,
    double spacingMeters = 120,
    double size = 14,
  }) {
    if (points.length < 2) return const [];

    final markers = <Marker>[];
    var walked = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final segLen = _distance.as(LengthUnit.Meter, a, b);
      var cursor = spacingMeters - walked;
      while (cursor <= segLen) {
        final t = cursor / segLen;
        final lat = a.latitude + (b.latitude - a.latitude) * t;
        final lng = a.longitude + (b.longitude - a.longitude) * t;
        final bearing = _bearing(a, b);
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: size + 4,
            height: size + 4,
            child: Transform.rotate(
              angle: bearing * math.pi / 180,
              child: Icon(Icons.navigation_rounded, size: size, color: color),
            ),
          ),
        );
        cursor += spacingMeters;
      }
      walked = (walked + segLen) % spacingMeters;
    }
    return markers;
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
