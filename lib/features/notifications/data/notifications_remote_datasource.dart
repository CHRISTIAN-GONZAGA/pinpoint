import 'package:dio/dio.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';

/// Remote API for announcements and user notifications.
class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<List<Announcement>> fetchAnnouncements() async {
    final response = await _api.get<Map<String, dynamic>>('/notifications/announcements');
    final list = response.data?['announcements'] as List<dynamic>? ?? [];
    return list.map((e) => Announcement.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<({List<AppNotification> items, int unreadCount})> fetchNotifications() async {
    final response = await _api.get<Map<String, dynamic>>('/notifications');
    final data = response.data ?? {};
    final list = data['notifications'] as List<dynamic>? ?? [];
    return (
      items: list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList(),
      unreadCount: data['unread_count'] as int? ?? 0,
    );
  }

  Future<void> markRead(int notificationId) async {
    await _api.post<Map<String, dynamic>>('/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _api.post<Map<String, dynamic>>('/notifications/read-all');
  }
}
