import 'package:dio/dio.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Fetches transportation overlay data from the PINPOINT API.
class TransportRemoteDataSource {
  TransportRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<List<JeepneyRoute>> fetchJeepneyRoutes() async {
    final raw = await fetchJeepneyRoutesRaw();
    return raw.map(JeepneyRoute.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> fetchJeepneyRoutesRaw() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/routes');
      final routes = response.data?['routes'] as List<dynamic>? ?? [];
      return routes.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw AppException(
        e.response?.data?['message'] as String? ??
            'Unable to load jeepney routes.',
      );
    }
  }

  Future<List<TricycleZone>> fetchTricycleZones() async {
    final raw = await fetchTricycleZonesRaw();
    return raw.map(TricycleZone.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTricycleZonesRaw() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/maps/tricycle-zones');
      final zones = response.data?['zones'] as List<dynamic>? ?? [];
      return zones.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw AppException(
        e.response?.data?['message'] as String? ??
            'Unable to load tricycle zones.',
      );
    }
  }

  Future<List<FareConfig>> fetchFares() async {
    final raw = await fetchFaresRaw();
    return raw.map(FareConfig.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> fetchFaresRaw() async {
    try {
      final response = await _api.get<Map<String, dynamic>>('/fares');
      final fares = response.data?['fares'] as List<dynamic>? ?? [];
      return fares.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw AppException(
        e.response?.data?['message'] as String? ?? 'Unable to load fare data.',
      );
    }
  }
}
