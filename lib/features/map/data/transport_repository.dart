import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/map/data/transport_asset_datasource.dart';
import 'package:pinpoint/features/map/data/transport_local_datasource.dart';
import 'package:pinpoint/features/map/data/transport_remote_datasource.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Repository for transportation overlay and fare data with offline cache.
class TransportRepository {
  TransportRepository({
    required TransportRemoteDataSource remoteDataSource,
    required TransportLocalDataSource localDataSource,
    required TransportAssetDataSource assetDataSource,
  })  : _remote = remoteDataSource,
        _local = localDataSource,
        _assets = assetDataSource;

  final TransportRemoteDataSource _remote;
  final TransportLocalDataSource _local;
  final TransportAssetDataSource _assets;

  List<JeepneyRoute>? _cachedRoutes;
  List<TricycleZone>? _cachedZones;
  List<FareConfig>? _cachedFares;

  Future<List<JeepneyRoute>> getJeepneyRoutes({bool forceRefresh = false}) async {
    if (_cachedRoutes != null && !forceRefresh) return _cachedRoutes!;
    final data = await loadAllTransportData();
    return data.routes;
  }

  Future<List<TricycleZone>> getTricycleZones({bool forceRefresh = false}) async {
    if (_cachedZones != null && !forceRefresh) return _cachedZones!;
    final data = await loadAllTransportData();
    return data.zones;
  }

  Future<List<FareConfig>> getFares({bool forceRefresh = false}) async {
    if (_cachedFares != null && !forceRefresh) return _cachedFares!;
    final data = await loadAllTransportData();
    return data.fares;
  }

  Future<({List<JeepneyRoute> routes, List<TricycleZone> zones, List<FareConfig> fares})>
      loadAllTransportData() async {
    if (!AppConstants.offlineFirstMode) {
      try {
        final routesRaw = await _remote.fetchJeepneyRoutesRaw();
        final zonesRaw = await _remote.fetchTricycleZonesRaw();
        final faresRaw = await _remote.fetchFaresRaw();
        _cachedRoutes = _parseRoutes(routesRaw);
        _cachedZones = _parseZones(zonesRaw);
        _cachedFares = _parseFares(faresRaw);
        if (_hasParsedData) {
          await _local.saveTransportBundle(
            routes: routesRaw,
            zones: zonesRaw,
            fares: faresRaw,
          );
          return _snapshot();
        }
      } catch (_) {
        // Fall through to bundled assets.
      }
    }

    await _loadFromBundledAssets();
    return _snapshot();
  }

  bool get _hasParsedData =>
      (_cachedRoutes?.isNotEmpty ?? false) ||
      (_cachedZones?.isNotEmpty ?? false) ||
      (_cachedFares?.isNotEmpty ?? false);

  Future<void> _loadFromBundledAssets() async {
    final routesRaw = await _assets.fetchJeepneyRoutesRaw();
    final zonesRaw = await _assets.fetchTricycleZonesRaw();
    final faresRaw = await _assets.fetchFaresRaw();

    _cachedRoutes = _parseRoutes(routesRaw);
    _cachedZones = _parseZones(zonesRaw);
    _cachedFares = _parseFares(faresRaw);

    if (_hasParsedData) {
      await _local.saveTransportBundle(
        routes: routesRaw,
        zones: zonesRaw,
        fares: faresRaw,
      );
      return;
    }

    // Last resort: try Hive cache (may have been seeded at startup).
    final bundle = await _local.loadTransportBundle();
    if (bundle != null) {
      _cachedRoutes = _parseRoutes(bundle.routes);
      _cachedZones = _parseZones(bundle.zones);
      _cachedFares = _parseFares(bundle.fares);
    }
  }

  List<JeepneyRoute> _parseRoutes(List<Map<String, dynamic>> raw) {
    final routes = <JeepneyRoute>[];
    for (final item in raw) {
      try {
        routes.add(JeepneyRoute.fromJson(item));
      } catch (_) {}
    }
    return routes;
  }

  List<TricycleZone> _parseZones(List<Map<String, dynamic>> raw) {
    final zones = <TricycleZone>[];
    for (final item in raw) {
      try {
        zones.add(TricycleZone.fromJson(item));
      } catch (_) {}
    }
    return zones;
  }

  List<FareConfig> _parseFares(List<Map<String, dynamic>> raw) {
    final fares = <FareConfig>[];
    for (final item in raw) {
      try {
        fares.add(FareConfig.fromJson(item));
      } catch (_) {}
    }
    return fares;
  }

  ({List<JeepneyRoute> routes, List<TricycleZone> zones, List<FareConfig> fares})
      _snapshot() => (
        routes: _cachedRoutes ?? [],
        zones: _cachedZones ?? [],
        fares: _cachedFares ?? [],
      );
}
