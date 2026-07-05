import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Helpers for route direction cues on the map.
abstract final class MapPolylineUtils {
  static const _distance = Distance();

  /// Places chevron markers along a polyline to show travel direction.
  static List<Marker> directionMarkers(
    List<LatLng> points, {
    required Color color,
    double spacingMeters = 90,
    double size = 16,
  }) {
    if (points.length < 2) return const [];

    final markers = <Marker>[];
    var walked = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final segLen = _distance.as(LengthUnit.Meter, a, b);
      if (segLen < 8) continue;

      var cursor = spacingMeters - walked;
      while (cursor <= segLen) {
        final t = cursor / segLen;
        final lat = a.latitude + (b.latitude - a.latitude) * t;
        final lng = a.longitude + (b.longitude - a.longitude) * t;
        final bearing = _bearing(a, b);
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: size + 12,
            height: size + 12,
            child: Transform.rotate(
              angle: (bearing - 45) * math.pi / 180,
              child: _DirectionArrow(color: color, size: size),
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

class _DirectionArrow extends StatelessWidget {
  const _DirectionArrow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(Icons.navigation_rounded, size: size - 2, color: color),
    );
  }
}
