import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Object? _decodeJson(String raw) => jsonDecode(raw);

/// Loads bundled JSON assets shipped with the app.
abstract final class AssetLoader {
  static Future<Map<String, dynamic>> loadJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = raw.length >= 64 * 1024
        ? await compute<String, Object?>(
            _decodeJson,
            raw,
            debugLabel: 'decode-json:$assetPath',
          )
        : jsonDecode(raw);
    return Map<String, dynamic>.from(decoded as Map);
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
  static const nationalHighways =
      'assets/data/transport/national_highways.json';
}
