import 'package:equatable/equatable.dart';

/// Public announcement from city administrators.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.priority,
    required this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['announcement_id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'normal',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final int id;
  final String title;
  final String content;
  final String category;
  final String priority;
  final DateTime publishedAt;

  bool get isHighPriority => priority == 'high';

  @override
  List<Object?> get props => [id, title, category, priority];
}

/// In-app notification for a registered user.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['notification_id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String? ?? 'general',
      read: json['read_status'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final int id;
  final String title;
  final String body;
  final String category;
  final bool read;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, title, read];
}
