import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';

/// OSRM walking/driving routes with in-memory cache and straight-line fallback.
class RoutingService {
  RoutingService({Dio? dio, this.offlineMode = false})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
                sendTimeout: const Duration(seconds: 3),
              ),
            );

  final Dio _dio;
  final bool offlineMode;
  final Distance _distance = const Distance();

  static const osrmTimeout = Duration(seconds: 3);
  static const _maxCacheEntries = 256;

  final Map<String, ({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      _cache = {};

  /// Fetches a walking route polyline from OSRM.
  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      getWalkingRoute(LatLng from, LatLng to) =>
      _getRoute(from, to, profile: 'foot');

  /// Fetches a driving route polyline from OSRM (tricycle / taxi).
  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      getDrivingRoute(LatLng from, LatLng to) =>
      _getRoute(from, to, profile: 'driving');

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      _getRoute(LatLng from, LatLng to, {required String profile}) async {
    if (offlineMode) return _straightLineFallback(from, to, profile: profile);

    final key = _cacheKey(from, to, profile);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.osrmBaseUrl}/route/v1/$profile/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      );
      final data = response.data;
      if (data == null || data['routes'] == null) {
        return _store(key, _straightLineFallback(from, to, profile: profile));
      }
      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        return _store(key, _straightLineFallback(from, to, profile: profile));
      }
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;
      final polyline = coordinates
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return _store(
        key,
        (
          polyline: polyline,
          distanceMeters: (route['distance'] as num).toDouble(),
          durationSeconds: (route['duration'] as num).round(),
        ),
      );
    } on DioException {
      return _store(key, _straightLineFallback(from, to, profile: profile));
    }
  }

  String _cacheKey(LatLng from, LatLng to, String profile) {
    String r(double v) => v.toStringAsFixed(4);
    return '$profile|${r(from.latitude)},${r(from.longitude)}|${r(to.latitude)},${r(to.longitude)}';
  }

  ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) _store(
    String key,
    ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) value,
  ) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
    return value;
  }

  ({List<LatLng> polyline, double distanceMeters, int durationSeconds})
      _straightLineFallback(LatLng from, LatLng to, {required String profile}) {
    final meters = distanceMeters(from, to);
    const walkMps = 1.4;
    const driveMps = 8.0;
    final speed = profile == 'foot' ? walkMps : driveMps;
    return (
      polyline: [from, to],
      distanceMeters: meters,
      durationSeconds: (meters / speed).round().clamp(60, 99999),
    );
  }

  double distanceMeters(LatLng from, LatLng to) =>
      _distance.as(LengthUnit.Meter, from, to);

  /// Snaps a tap to the nearest drivable road using OSRM Nearest.
  Future<LatLng> snapToNearestRoad(LatLng point) async {
    if (offlineMode) return point;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.osrmBaseUrl}/nearest/v1/driving/'
        '${point.longitude},${point.latitude}',
        queryParameters: {'number': 1},
      );
      final waypoints = response.data?['waypoints'] as List<dynamic>? ?? [];
      if (waypoints.isEmpty) return point;
      final location = (waypoints.first as Map<String, dynamic>)['location'] as List;
      return LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble());
    } on DioException {
      return point;
    }
  }

  /// Snaps a freehand finger trace onto the road network (OSRM Match).
  /// Falls back to chaining driving routes between sparse waypoints.
  Future<List<LatLng>> matchTraceToRoads(List<LatLng> rawTrace) async {
    if (rawTrace.length < 2) return rawTrace;
    if (offlineMode) return List.of(rawTrace);

    final sampled = _sampleTrace(rawTrace, minSpacingMeters: 35);
    if (sampled.length < 2) return sampled;

    try {
      final coords = sampled
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.osrmBaseUrl}/match/v1/driving/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'tidy': 'true',
        },
      );
      final matchings = response.data?['matchings'] as List<dynamic>? ?? [];
      if (matchings.isNotEmpty) {
        final geometry =
            (matchings.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>? ?? [];
        if (coordinates.length >= 2) {
          return coordinates
              .map(
                (c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ),
              )
              .toList();
        }
      }
    } on DioException {
      // Fall through to waypoint routing.
    }

    return routeThroughWaypoints(sampled);
  }

  /// Chains driving routes through an ordered list of waypoints.
  Future<List<LatLng>> routeThroughWaypoints(List<LatLng> waypoints) async {
    if (waypoints.isEmpty) return const [];
    if (waypoints.length == 1) return [waypoints.first];

    final corridor = <LatLng>[];
    for (var i = 0; i < waypoints.length - 1; i++) {
      final from = waypoints[i];
      final to = waypoints[i + 1];
      final segment = await getDrivingRoute(from, to);
      final points = segment.polyline.isNotEmpty ? segment.polyline : [from, to];
      if (corridor.isEmpty) {
        corridor.addAll(points);
      } else {
        corridor.addAll(points.skip(1));
      }
    }
    return corridor;
  }

  /// Projects [point] onto the nearest location along [corridor].
  LatLng projectOntoPolyline(LatLng point, List<LatLng> corridor) {
    if (corridor.isEmpty) return point;
    if (corridor.length == 1) return corridor.first;

    var bestPoint = corridor.first;
    var bestDist = double.infinity;
    for (var i = 0; i < corridor.length - 1; i++) {
      final a = corridor[i];
      final b = corridor[i + 1];
      final projected = _closestPointOnSegment(point, a, b);
      final d = distanceMeters(point, projected);
      if (d < bestDist) {
        bestDist = d;
        bestPoint = projected;
      }
    }
    return bestPoint;
  }

  List<LatLng> _sampleTrace(List<LatLng> raw, {required double minSpacingMeters}) {
    if (raw.isEmpty) return const [];
    final out = <LatLng>[raw.first];
    for (var i = 1; i < raw.length; i++) {
      if (distanceMeters(out.last, raw[i]) >= minSpacingMeters) {
        out.add(raw[i]);
      }
    }
    if (out.last != raw.last) out.add(raw.last);
    // Cap match request size for public OSRM.
    if (out.length <= 80) return out;
    final step = (out.length / 70).ceil();
    final sparse = <LatLng>[];
    for (var i = 0; i < out.length; i += step) {
      sparse.add(out[i]);
    }
    if (sparse.last != out.last) sparse.add(out.last);
    return sparse;
  }

  LatLng _closestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final ax = a.longitude;
    final ay = a.latitude;
    final bx = b.longitude;
    final by = b.latitude;
    final px = p.longitude;
    final py = p.latitude;
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return a;
    final t = (((px - ax) * dx) + ((py - ay) * dy)) / ((dx * dx) + (dy * dy));
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(ay + dy * clamped, ax + dx * clamped);
  }
}
