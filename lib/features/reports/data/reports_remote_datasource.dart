import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';

/// User issue reports for administrators.
class ReportsRemoteDataSource {
  ReportsRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<void> submitReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/reports',
      data: {
        'category': category,
        'description': description,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
  }
}
