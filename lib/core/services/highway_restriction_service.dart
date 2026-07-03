import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/local/asset_loader.dart';

/// Detects whether a path would use national highways (tricycle-restricted).
class HighwayRestrictionService {
  HighwayRestrictionService({
    List<List<LatLng>>? corridors,
    double bufferMeters = 80,
  })  : _corridors = corridors ?? [],
        _bufferMeters = bufferMeters;

  final List<List<LatLng>> _corridors;
  final double _bufferMeters;
  final Distance _distance = const Distance();

  static HighwayRestrictionService? _cached;

  /// Loads highway corridors from bundled assets (cached after first load).
  static Future<HighwayRestrictionService> load() async {
    if (_cached != null) return _cached!;
    final data = await AssetLoader.loadJson(AssetPaths.nationalHighways);
    final buffer = (data['buffer_meters'] as num?)?.toDouble() ?? 80;
    final corridors = <List<LatLng>>[];
    for (final corridor in data['corridors'] as List<dynamic>? ?? []) {
      final map = corridor as Map<String, dynamic>;
      final ring = map['polyline'] as List<dynamic>? ?? [];
      corridors.add(
        ring.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList(),
      );
    }
    _cached = HighwayRestrictionService(corridors: corridors, bufferMeters: buffer);
    return _cached!;
  }

  /// Returns true when any part of [path] comes within the highway buffer zone.
  bool pathUsesNationalHighway(List<LatLng> path) {
    if (path.length < 2 || _corridors.isEmpty) return false;
    for (var i = 0; i < path.length - 1; i++) {
      if (segmentUsesNationalHighway(path[i], path[i + 1])) return true;
    }
    return false;
  }

  /// Returns true when a straight or routed segment crosses a highway corridor.
  bool segmentUsesNationalHighway(LatLng from, LatLng to) {
    for (final corridor in _corridors) {
      for (var i = 0; i < corridor.length - 1; i++) {
        final dist = _segmentToSegmentDistanceMeters(
          from,
          to,
          corridor[i],
          corridor[i + 1],
        );
        if (dist <= _bufferMeters) return true;
      }
    }
    return false;
  }

  /// Minimum distance between two line segments in meters.
  double _segmentToSegmentDistanceMeters(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
    const samples = 8;
    var minDist = double.infinity;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final p = LatLng(
        a1.latitude + (a2.latitude - a1.latitude) * t,
        a1.longitude + (a2.longitude - a1.longitude) * t,
      );
      minDist = math.min(minDist, _pointToCorridorDistanceMeters(p, b1, b2));
    }
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final p = LatLng(
        b1.latitude + (b2.latitude - b1.latitude) * t,
        b1.longitude + (b2.longitude - b1.longitude) * t,
      );
      minDist = math.min(minDist, _pointToSegmentDistanceMeters(p, a1, a2));
    }
    return minDist;
  }

  double _pointToCorridorDistanceMeters(LatLng point, LatLng segStart, LatLng segEnd) =>
      _pointToSegmentDistanceMeters(point, segStart, segEnd);

  double _pointToSegmentDistanceMeters(LatLng point, LatLng segStart, LatLng segEnd) {
    final segLen = _distance.as(LengthUnit.Meter, segStart, segEnd);
    if (segLen < 1) return _distance.as(LengthUnit.Meter, point, segStart);

    final samples = math.max(4, (segLen / 40).ceil());
    var minDist = double.infinity;
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final sample = LatLng(
        segStart.latitude + (segEnd.latitude - segStart.latitude) * t,
        segStart.longitude + (segEnd.longitude - segStart.longitude) * t,
      );
      minDist = math.min(minDist, _distance.as(LengthUnit.Meter, point, sample));
    }
    return minDist;
  }
}
