import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/admin/data/admin_remote_datasource.dart';

class AdminRepository {
  AdminRepository({required AdminRemoteDataSource remote, required ApiClient apiClient})
      : _remote = remote,
        _apiClient = apiClient;

  final AdminRemoteDataSource _remote;
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      return await _remote.fetchDashboard();
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getReports({String? status}) async {
    try {
      return await _remote.fetchReports(status: status);
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  Future<void> publishAnnouncement({
    required String title,
    required String content,
    String category = 'general',
    String priority = 'normal',
  }) async {
    try {
      await _remote.createAnnouncement(
        title: title,
        content: content,
        category: category,
        priority: priority,
      );
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  Future<void> resolveReport(int reportId, {String? notes}) async {
    try {
      await _remote.updateReportStatus(
        reportId: reportId,
        status: 'resolved',
        adminNotes: notes,
      );
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }
}
