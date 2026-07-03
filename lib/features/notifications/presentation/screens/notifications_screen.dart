import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/notifications/presentation/viewmodels/notifications_notifier.dart';

/// Lists user notifications and announcements.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsNotifierProvider.notifier).loadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationsNotifierProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? const Center(child: Text('No notifications yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: state.notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = state.notifications[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          item.read ? Icons.notifications_none : Icons.notifications_active,
                          color: item.read
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(item.title),
                        subtitle: Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                        onTap: item.read
                            ? null
                            : () => ref
                                .read(notificationsNotifierProvider.notifier)
                                .markRead(item.id),
                      ),
                    );
                  },
                ),
    );
  }
}
