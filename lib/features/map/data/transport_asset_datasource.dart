import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/features/map/data/transport_local_datasource.dart';

/// Loads transport data from bundled JSON assets.
class TransportAssetDataSource {
  TransportAssetDataSource({required TransportLocalDataSource local}) : _local = local;

  final TransportLocalDataSource _local;

  Future<List<Map<String, dynamic>>> fetchJeepneyRoutesRaw() =>
      AssetLoader.loadJsonList(AssetPaths.jeepneyRoutes, 'routes');

  Future<List<Map<String, dynamic>>> fetchTricycleZonesRaw() =>
      AssetLoader.loadJsonList(AssetPaths.tricycleZones, 'zones');

  Future<List<Map<String, dynamic>>> fetchFaresRaw() =>
      AssetLoader.loadJsonList(AssetPaths.fares, 'fares');

  Future<void> cacheToLocal() async {
    final routes = await fetchJeepneyRoutesRaw();
    final zones = await fetchTricycleZonesRaw();
    final fares = await fetchFaresRaw();
    await _local.saveTransportBundle(routes: routes, zones: zones, fares: fares);
  }
}
