import 'package:dio/dio.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/notifications/data/notifications_local_datasource.dart';
import 'package:pinpoint/features/notifications/data/notifications_remote_datasource.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';

/// Repository for announcements and notifications.
class NotificationsRepository {
  NotificationsRepository({
    required NotificationsRemoteDataSource remote,
    required NotificationsLocalDataSource local,
    required ApiClient apiClient,
  })  : _remote = remote,
        _local = local,
        _apiClient = apiClient;

  final NotificationsRemoteDataSource _remote;
  final NotificationsLocalDataSource _local;
  final ApiClient _apiClient;

  Future<List<Announcement>> getAnnouncements() async {
    var local = <Announcement>[];
    try {
      local = (await _local.getAnnouncements()).map(Announcement.fromJson).toList();
    } catch (_) {}

    if (AppConstants.offlineFirstMode) return local;

    try {
      return await _remote.fetchAnnouncements().timeout(const Duration(seconds: 8));
    } catch (_) {
      return local;
    }
  }

  Future<({List<AppNotification> items, int unreadCount})> getNotifications() async {
    if (AppConstants.offlineFirstMode) {
      final announcements = await getAnnouncements();
      final items = announcements
          .map(
            (announcement) => AppNotification(
              id: announcement.id,
              title: announcement.title,
              body: announcement.content,
              category: announcement.category,
              read: false,
              createdAt: announcement.publishedAt,
            ),
          )
          .toList();
      return (items: items, unreadCount: items.length);
    }
    try {
      return await _remote.fetchNotifications();
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  Future<void> markRead(int notificationId) async {
    if (AppConstants.offlineFirstMode) return;
    try {
      await _remote.markRead(notificationId);
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }

  Future<void> markAllRead() async {
    if (AppConstants.offlineFirstMode) return;
    try {
      await _remote.markAllRead();
    } on DioException catch (error) {
      throw _apiClient.mapError(error);
    }
  }
}
