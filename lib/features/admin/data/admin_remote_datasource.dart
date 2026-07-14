import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

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

  Future<List<JeepneyRoute>> fetchAdminRoutes() async {
    final response = await _api.get<Map<String, dynamic>>('/admin/routes');
    final list = response.data?['routes'] as List<dynamic>? ?? [];
    return list
        .map((item) => JeepneyRoute.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<JeepneyRoute> createRoute(Map<String, dynamic> payload) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/routes',
      data: payload,
    );
    return JeepneyRoute.fromJson(response.data ?? {});
  }

  Future<JeepneyRoute> updateRoute(int routeId, Map<String, dynamic> payload) async {
    final response = await _api.patch<Map<String, dynamic>>(
      '/admin/routes/$routeId',
      data: payload,
    );
    return JeepneyRoute.fromJson(response.data ?? {});
  }

  Future<void> deleteRoute(int routeId) async {
    await _api.delete<Map<String, dynamic>>('/admin/routes/$routeId');
  }

  Future<JeepneyRoute> replaceStops(int routeId, List<Map<String, dynamic>> stops) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/routes/$routeId/stops',
      data: {'stops': stops},
    );
    return JeepneyRoute.fromJson(response.data ?? {});
  }
}
