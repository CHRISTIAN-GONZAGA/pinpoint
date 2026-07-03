import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';

/// OSRM walking route between two points.
class RoutingService {
  RoutingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
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
        throw const AppException('Unable to calculate walking route.');
      }
      final routes = data['routes'] as List;
      if (routes.isEmpty) throw const AppException('No walking route found.');
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
      throw const AppException('Routing service unavailable. Try again later.');
    }
  }

  double distanceMeters(LatLng from, LatLng to) =>
      _distance.as(LengthUnit.Meter, from, to);
}
