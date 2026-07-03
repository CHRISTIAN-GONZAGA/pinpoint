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
    if (AppConstants.offlineFirstMode) {
      return _loadOfflineRoutes();
    }
    try {
      final raw = await _remote.fetchJeepneyRoutesRaw();
      _cachedRoutes = raw.map(JeepneyRoute.fromJson).toList();
      await _local.saveTransportBundle(
        routes: raw,
        zones: (await _local.loadTransportBundle())?.zones ?? [],
        fares: (await _local.loadTransportBundle())?.fares ?? [],
      );
      return _cachedRoutes!;
    } catch (_) {
      return _loadOfflineRoutes();
    }
  }

  Future<List<TricycleZone>> getTricycleZones({bool forceRefresh = false}) async {
    if (_cachedZones != null && !forceRefresh) return _cachedZones!;
    if (AppConstants.offlineFirstMode) {
      return _loadOfflineZones();
    }
    try {
      final raw = await _remote.fetchTricycleZonesRaw();
      _cachedZones = raw.map(TricycleZone.fromJson).toList();
      final existing = await _local.loadTransportBundle();
      await _local.saveTransportBundle(
        routes: existing?.routes ?? [],
        zones: raw,
        fares: existing?.fares ?? [],
      );
      return _cachedZones!;
    } catch (_) {
      return _loadOfflineZones();
    }
  }

  Future<List<FareConfig>> getFares({bool forceRefresh = false}) async {
    if (_cachedFares != null && !forceRefresh) return _cachedFares!;
    if (AppConstants.offlineFirstMode) {
      return _loadOfflineFares();
    }
    try {
      final raw = await _remote.fetchFaresRaw();
      _cachedFares = raw.map(FareConfig.fromJson).toList();
      final existing = await _local.loadTransportBundle();
      await _local.saveTransportBundle(
        routes: existing?.routes ?? [],
        zones: existing?.zones ?? [],
        fares: raw,
      );
      return _cachedFares!;
    } catch (_) {
      return _loadOfflineFares();
    }
  }

  Future<({List<JeepneyRoute> routes, List<TricycleZone> zones, List<FareConfig> fares})>
      loadAllTransportData() async {
    if (AppConstants.offlineFirstMode) {
      await Future.wait([_loadOfflineRoutes(), _loadOfflineZones(), _loadOfflineFares()]);
      return (
        routes: _cachedRoutes ?? [],
        zones: _cachedZones ?? [],
        fares: _cachedFares ?? [],
      );
    }
    try {
      final routesRaw = await _remote.fetchJeepneyRoutesRaw();
      final zonesRaw = await _remote.fetchTricycleZonesRaw();
      final faresRaw = await _remote.fetchFaresRaw();
      _cachedRoutes = routesRaw.map(JeepneyRoute.fromJson).toList();
      _cachedZones = zonesRaw.map(TricycleZone.fromJson).toList();
      _cachedFares = faresRaw.map(FareConfig.fromJson).toList();
      await _local.saveTransportBundle(routes: routesRaw, zones: zonesRaw, fares: faresRaw);
    } catch (_) {
      await Future.wait([_loadOfflineRoutes(), _loadOfflineZones(), _loadOfflineFares()]);
    }
    return (
      routes: _cachedRoutes ?? [],
      zones: _cachedZones ?? [],
      fares: _cachedFares ?? [],
    );
  }

  Future<List<JeepneyRoute>> _loadOfflineRoutes() async {
    var bundle = await _local.loadTransportBundle();
    if (bundle == null || bundle.routes.isEmpty) {
      await _assets.cacheToLocal();
      bundle = await _local.loadTransportBundle();
    }
    if (bundle == null) return _cachedRoutes ?? [];
    _cachedRoutes = bundle.routes.map(JeepneyRoute.fromJson).toList();
    return _cachedRoutes!;
  }

  Future<List<TricycleZone>> _loadOfflineZones() async {
    var bundle = await _local.loadTransportBundle();
    if (bundle == null || bundle.zones.isEmpty) {
      await _assets.cacheToLocal();
      bundle = await _local.loadTransportBundle();
    }
    if (bundle == null) return _cachedZones ?? [];
    _cachedZones = bundle.zones.map(TricycleZone.fromJson).toList();
    return _cachedZones!;
  }

  Future<List<FareConfig>> _loadOfflineFares() async {
    var bundle = await _local.loadTransportBundle();
    if (bundle == null || bundle.fares.isEmpty) {
      await _assets.cacheToLocal();
      bundle = await _local.loadTransportBundle();
    }
    if (bundle == null) return _cachedFares ?? [];
    _cachedFares = bundle.fares.map(FareConfig.fromJson).toList();
    return _cachedFares!;
  }
}
