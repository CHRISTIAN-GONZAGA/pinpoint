import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';

/// OSRM walking route between two points.
class RoutingService {
  RoutingService({Dio? dio, this.offlineMode = false}) : _dio = dio ?? Dio();

  final Dio _dio;
  final bool offlineMode;
  final Distance _distance = const Distance();

  /// Fetches a walking route polyline from OSRM.
  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      getWalkingRoute(LatLng from, LatLng to) =>
      _getRoute(from, to, profile: 'foot');

  /// Fetches a driving route polyline from OSRM (taxi / tricycle path check).
  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      getDrivingRoute(LatLng from, LatLng to) =>
      _getRoute(from, to, profile: 'driving');

  Future<({List<LatLng> polyline, double distanceMeters, int durationSeconds})>
      _getRoute(LatLng from, LatLng to, {required String profile}) async {
    if (offlineMode) return _straightLineFallback(from, to);
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
        return _straightLineFallback(from, to);
      }
      final routes = data['routes'] as List;
      if (routes.isEmpty) return _straightLineFallback(from, to);
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;
      final polyline = coordinates
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return (
        polyline: polyline,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).round(),
      );
    } on DioException {
      return _straightLineFallback(from, to);
    }
  }

  ({List<LatLng> polyline, double distanceMeters, int durationSeconds})
      _straightLineFallback(LatLng from, LatLng to) {
    final meters = distanceMeters(from, to);
    const walkMps = 1.4;
    const driveMps = 8.0;
    final speed = meters < 2000 ? walkMps : driveMps;
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
}
