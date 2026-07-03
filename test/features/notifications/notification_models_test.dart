import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/features/notifications/domain/notification_models.dart';

void main() {
  test('Announcement parses priority flag', () {
    final announcement = Announcement.fromJson({
      'announcement_id': 1,
      'title': 'Fare Update',
      'content': 'New matrix published.',
      'category': 'transport',
      'priority': 'high',
      'published_at': '2026-01-01T00:00:00',
    });

    expect(announcement.isHighPriority, isTrue);
    expect(announcement.title, 'Fare Update');
  });

  test('AppNotification parses read status', () {
    final notification = AppNotification.fromJson({
      'notification_id': 9,
      'title': 'Welcome',
      'body': 'Hello',
      'category': 'general',
      'read_status': false,
      'created_at': '2026-01-01T00:00:00',
    });

    expect(notification.read, isFalse);
    expect(notification.id, 9);
  });
}
