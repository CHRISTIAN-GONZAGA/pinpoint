import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/features/map/data/transport_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Imports bundled JSON into Hive on first launch (and on developer reseed).
class LocalSeedService {
  LocalSeedService({
    required TransportLocalDataSource transportLocal,
  }) : _transportLocal = transportLocal;

  final TransportLocalDataSource _transportLocal;

  Future<bool> isSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.localSeedCompleteKey) ?? false;
  }

  Future<void> seedIfNeeded({bool force = false}) async {
    if (!force && await isSeeded()) return;
    await seedAll();
  }

  Future<void> seedAll() async {
    final routes = await AssetLoader.loadJsonList(AssetPaths.jeepneyRoutes, 'routes');
    final zones = await AssetLoader.loadJsonList(AssetPaths.tricycleZones, 'zones');
    final fares = await AssetLoader.loadJsonList(AssetPaths.fares, 'fares');
    final attractions = await AssetLoader.loadJsonList(AssetPaths.attractions, 'attractions');
    final establishments =
        await AssetLoader.loadJsonList(AssetPaths.establishments, 'establishments');
    final emergency = await AssetLoader.loadJsonList(AssetPaths.emergency, 'contacts');
    final knowledge = await AssetLoader.loadJsonList(AssetPaths.knowledge, 'documents');
    final announcements =
        await AssetLoader.loadJsonList(AssetPaths.announcements, 'announcements');

    await _transportLocal.saveTransportBundle(routes: routes, zones: zones, fares: fares);

    final placesBox = await Hive.openBox(AppConstants.placesCacheBoxName);
    await placesBox.put('attractions', attractions);
    await placesBox.put('establishments', establishments);
    await placesBox.put('emergency', emergency);

    final knowledgeBox = await Hive.openBox(AppConstants.knowledgeCacheBoxName);
    await knowledgeBox.put('documents', knowledge);

    final announcementsBox = await Hive.openBox(AppConstants.announcementsCacheBoxName);
    await announcementsBox.put('announcements', announcements);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.localSeedCompleteKey, true);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.localSeedCompleteKey, false);
    await Hive.deleteBoxFromDisk(AppConstants.transportCacheBoxName);
    await Hive.deleteBoxFromDisk(AppConstants.placesCacheBoxName);
    await Hive.deleteBoxFromDisk(AppConstants.knowledgeCacheBoxName);
    await Hive.deleteBoxFromDisk(AppConstants.announcementsCacheBoxName);
    await Hive.deleteBoxFromDisk(AppConstants.favoritesBoxName);
    await Hive.deleteBoxFromDisk(AppConstants.historyBoxName);
    await Hive.deleteBoxFromDisk(AppConstants.routeCacheBoxName);
    await seedAll();
  }
}
