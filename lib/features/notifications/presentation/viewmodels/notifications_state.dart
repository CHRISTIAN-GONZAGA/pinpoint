import 'package:equatable/equatable.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.announcements = const [],
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<Announcement> announcements;
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? errorMessage;

  NotificationsState copyWith({
    List<Announcement>? announcements,
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      announcements: announcements ?? this.announcements,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [announcements, notifications, unreadCount, isLoading];
}
