import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/reports/data/reports_remote_datasource.dart';

class ReportsRepository {
  ReportsRepository({required ReportsRemoteDataSource remote, required ApiClient apiClient})
      : _remote = remote,
        _apiClient = apiClient;

  final ReportsRemoteDataSource _remote;
  final ApiClient _apiClient;

  Future<void> submit({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _remote.submitReport(
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
      );
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }
}
