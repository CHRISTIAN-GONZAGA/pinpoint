import 'dart:async';

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

  static const _apiTimeout = Duration(seconds: 8);

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

  /// Loads bundled/local transport data immediately — no network wait.
  Future<({List<JeepneyRoute> routes, List<TricycleZone> zones, List<FareConfig> fares})>
      loadAllTransportData() async {
    if (_hasParsedData) return _snapshot();

    await _loadFromBundledAssets();
    if (_hasParsedData) return _snapshot();

    final bundle = await _local.loadTransportBundle();
    if (bundle != null) {
      _cachedRoutes = _parseRoutes(bundle.routes);
      _cachedZones = _parseZones(bundle.zones);
      _cachedFares = _parseFares(bundle.fares);
    }

    return _snapshot();
  }

  /// Fetches fresh data from the API when online (call in background).
  Future<({List<JeepneyRoute> routes, List<TricycleZone> zones, List<FareConfig> fares})>
      refreshFromRemote() async {
    if (AppConstants.offlineFirstMode) return _snapshot();

    final bundledBefore = _cachedRoutes ?? [];

    try {
      final results = await Future.wait([
        _remote.fetchJeepneyRoutesRaw().timeout(_apiTimeout),
        _remote.fetchTricycleZonesRaw().timeout(_apiTimeout),
        _remote.fetchFaresRaw().timeout(_apiTimeout),
      ]).timeout(const Duration(seconds: 10));

      final remoteRoutes = _parseRoutes(results[0]);
      final remoteZones = _parseZones(results[1]);
      final remoteFares = _parseFares(results[2]);

      // Prefer non-empty remote network so admin-managed routes reach passengers.
      if (_shouldUseRemoteRoutes(bundledBefore, remoteRoutes)) {
        _cachedRoutes = remoteRoutes;
      }

      if (remoteZones.isNotEmpty) _cachedZones = remoteZones;
      if (remoteFares.isNotEmpty) _cachedFares = remoteFares;

      if (_hasParsedData) {
        await _local.saveTransportBundle(
          routes: (_cachedRoutes ?? [])
              .map((r) => _routeToJson(r))
              .toList(),
          zones: results[1],
          fares: results[2],
        );
      }
    } catch (_) {
      // Keep bundled/local data already in memory.
    }

    return _snapshot();
  }

  /// Prefer remote routes whenever the API returns a usable active network.
  bool _shouldUseRemoteRoutes(
    List<JeepneyRoute> bundled,
    List<JeepneyRoute> remote,
  ) {
    if (remote.isEmpty) return false;
    final activeRemote = remote.where((r) => r.activeStatus).toList();
    if (activeRemote.isEmpty) return false;
    // Always trust remote admin truth when present; keep bundle if remote parse failed partially.
    if (bundled.isEmpty) return true;
    return activeRemote.isNotEmpty;
  }

  Map<String, dynamic> _routeToJson(JeepneyRoute route) {
    return {
      'route_id': route.routeId,
      'code': route.routeCode,
      'name': route.routeName,
      'color': route.colorHex,
      'description': route.description,
      'operating_hours': route.operatingHours,
      'bidirectional': route.bidirectional,
      'street_segments': route.streetSegments,
      'vehicle_type': route.vehicleType,
      'base_fare': route.baseFare,
      'additional_fare': route.additionalFare,
      'active_status': route.activeStatus,
      'ordered_stops': route.stops
          .map(
            (s) => {
              'id': s.stopKey ?? '${route.routeCode}_${s.order}',
              'name': s.name,
              'lat': s.latitude,
              'lng': s.longitude,
              'verified': s.verified,
              if (s.description != null) 'description': s.description,
            },
          )
          .toList(),
      'corridor_geojson': {
        'type': 'LineString',
        'coordinates': route.polyline
            .map((p) => [p.longitude, p.latitude])
            .toList(),
      },
    };
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
