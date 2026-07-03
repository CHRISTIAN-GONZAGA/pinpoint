import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Stores the most recent planned routes for offline reference.
class RouteCacheService {
  Future<Box<dynamic>> get _box async => Hive.openBox(AppConstants.routeCacheBoxName);

  Future<void> saveRoute({
    required PlannedRoute route,
    required String originLabel,
    required String destinationLabel,
  }) async {
    final box = await _box;
    final payload = {
      'origin_label': originLabel,
      'destination_label': destinationLabel,
      'distance_label': route.distanceLabel,
      'duration_label': route.durationLabel,
      'estimated_fare': route.estimatedFare,
      'steps': route.steps
          .map(
            (step) => {
              'instruction': step.instruction,
              'duration_label': step.durationLabel,
              'type': step.type.name,
            },
          )
          .toList(),
      'saved_at': DateTime.now().toIso8601String(),
    };
    final existing = await getRecentRoutes();
    existing.insert(0, payload);
    await box.put('routes', existing.take(10).toList());
  }

  Future<List<Map<String, dynamic>>> getRecentRoutes() async {
    final box = await _box;
    final raw = box.get('routes');
    if (raw is! List) return [];
    return raw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> clear() async {
    final box = await _box;
    await box.delete('routes');
  }
}
