import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads bundled JSON assets shipped with the app.
abstract final class AssetLoader {
  static Future<Map<String, dynamic>> loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> loadJsonList(
    String assetPath,
    String listKey,
  ) async {
    final data = await loadJson(assetPath);
    final list = data[listKey] as List<dynamic>? ?? [];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}

/// Bundled asset paths for offline-first seeding.
abstract final class AssetPaths {
  static const jeepneyRoutes = 'assets/data/routes/jeepney_routes.json';
  static const tricycleZones = 'assets/data/transport/tricycle_zones.json';
  static const fares = 'assets/data/transport/fares.json';
  static const attractions = 'assets/data/tourism/attractions.json';
  static const establishments = 'assets/data/tourism/establishments.json';
  static const emergency = 'assets/data/emergency/emergency.json';
  static const knowledge = 'assets/data/knowledge/knowledge_base.json';
  static const announcements = 'assets/data/system/announcements.json';
  static const nationalHighways = 'assets/data/transport/national_highways.json';
}
