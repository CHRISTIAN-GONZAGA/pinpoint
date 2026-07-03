import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';

/// Administrator API for dashboard and content management.
class AdminRemoteDataSource {
  AdminRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<Map<String, dynamic>> fetchDashboard() async {
    final response = await _api.get<Map<String, dynamic>>('/admin/dashboard');
    return response.data ?? {};
  }

  Future<List<Map<String, dynamic>>> fetchReports({String? status}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/admin/reports',
      queryParameters: status != null ? {'status': status} : null,
    );
    final list = response.data?['reports'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    String category = 'general',
    String priority = 'normal',
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/admin/announcements',
      data: {
        'title': title,
        'content': content,
        'category': category,
        'priority': priority,
      },
    );
  }

  Future<void> updateReportStatus({
    required int reportId,
    required String status,
    String? adminNotes,
  }) async {
    await _api.patch<Map<String, dynamic>>(
      '/admin/reports/$reportId',
      data: {
        'status': status,
        'admin_notes': ?adminNotes,
      },
    );
  }
}
