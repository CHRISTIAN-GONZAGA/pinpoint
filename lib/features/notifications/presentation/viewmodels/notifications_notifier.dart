import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_state.dart';

/// Loads announcements and user notifications.
class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() => const NotificationsState();

  Future<void> loadAnnouncements() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final announcements = await ref.read(notificationsRepositoryProvider).getAnnouncements();
      state = state.copyWith(isLoading: false, announcements: announcements);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(notificationsRepositoryProvider).getNotifications();
      state = state.copyWith(
        isLoading: false,
        notifications: result.items,
        unreadCount: result.unreadCount,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> markRead(int notificationId) async {
    await ref.read(notificationsRepositoryProvider).markRead(notificationId);
    await loadNotifications();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    await loadNotifications();
  }
}

final notificationsNotifierProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(NotificationsNotifier.new);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsNotifierProvider).unreadCount;
});
