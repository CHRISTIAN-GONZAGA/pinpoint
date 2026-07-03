import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/local/asset_loader.dart';

/// Cached announcements for offline notifications screen.
class NotificationsLocalDataSource {
  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final box = await Hive.openBox(AppConstants.announcementsCacheBoxName);
    final raw = box.get('announcements');
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return AssetLoader.loadJsonList(AssetPaths.announcements, 'announcements');
  }
}
