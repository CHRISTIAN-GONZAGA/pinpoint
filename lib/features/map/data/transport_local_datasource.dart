import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';

/// Persists transport overlay data for offline map use.
class TransportLocalDataSource {
  static const _routesKey = 'jeepney_routes';
  static const _zonesKey = 'tricycle_zones';
  static const _faresKey = 'fares';

  Future<Box<dynamic>> get _box async => Hive.openBox(AppConstants.transportCacheBoxName);

  Future<void> saveTransportBundle({
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> zones,
    required List<Map<String, dynamic>> fares,
  }) async {
    final box = await _box;
    await box.put(_routesKey, routes);
    await box.put(_zonesKey, zones);
    await box.put(_faresKey, fares);
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  Future<({List<Map<String, dynamic>> routes, List<Map<String, dynamic>> zones, List<Map<String, dynamic>> fares})?>
      loadTransportBundle() async {
    final box = await _box;
    final routes = box.get(_routesKey);
    final zones = box.get(_zonesKey);
    final fares = box.get(_faresKey);
    if (routes is! List || zones is! List || fares is! List) return null;
    return (
      routes: _castMapList(routes),
      zones: _castMapList(zones),
      fares: _castMapList(fares),
    );
  }

  List<Map<String, dynamic>> _castMapList(List<dynamic> raw) {
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
