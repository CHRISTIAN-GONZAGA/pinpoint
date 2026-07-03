// ignore_for_file: avoid_print
/// CI gate: fails if production bundled assets contain unverified coordinates.
/// Run: dart run scripts/verify_bundled_data.dart
import 'dart:convert';
import 'dart:io';

void main() {
  var failed = false;

  failed = _checkJeepneyRoutes() || failed;
  failed = _checkEstablishments() || failed;
  failed = _checkAttractions() || failed;
  failed = _checkTricycleZones() || failed;

  if (failed) {
    stderr.writeln('\n❌ Bundled data verification failed.');
    stderr.writeln('See scripts/geocode_stops.py and data/geocode_review.json workflow.');
    exit(1);
  }
  print('✅ All bundled production data passes verification gates.');
}

bool _checkJeepneyRoutes() {
  final path = 'assets/data/routes/jeepney_routes.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path');
    return true;
  }

  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final routes = root['routes'] as List<dynamic>? ?? [];
  var failed = false;

  for (final raw in routes) {
    final route = Map<String, dynamic>.from(raw as Map);
    final code = route['code'] ?? route['route_code'] ?? '?';
    final stops = _readStops(route);

    for (final stop in stops) {
      final verified = stop['verified'] as bool? ?? _legacyAssumeVerified(stop);
      final lat = stop['lat'] ?? stop['latitude'];
      final lng = stop['lng'] ?? stop['longitude'];

      if (verified != true) {
        stderr.writeln('[$code] Unverified stop "${stop['name'] ?? stop['stop_name']}": verified must be true in production.');
        failed = true;
        continue;
      }
      if (lat == null || lng == null) {
        stderr.writeln('[$code] Verified stop "${stop['name'] ?? stop['stop_name']}" missing coordinates.');
        failed = true;
      }
    }

    final corridor = route['corridor_geojson'];
    if (corridor == null && (route['geojson'] == null)) {
      stderr.writeln('[$code] Missing corridor_geojson or geojson polyline.');
      failed = true;
    }
  }

  return failed;
}

List<Map<String, dynamic>> _readStops(Map<String, dynamic> route) {
  if (route['ordered_stops'] is List) {
    return (route['ordered_stops'] as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }
  if (route['stops'] is List) {
    return (route['stops'] as List).map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }
  return [];
}

bool _legacyAssumeVerified(Map<String, dynamic> stop) {
  // Legacy schema without verified flag — treat as unverified for CI.
  return stop.containsKey('verified') ? false : false;
}

bool _checkEstablishments() {
  return _checkPlaceList('assets/data/tourism/establishments.json', 'establishments');
}

bool _checkAttractions() {
  return _checkPlaceList('assets/data/tourism/attractions.json', 'attractions');
}

bool _checkPlaceList(String path, String key) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final items = root[key] as List<dynamic>? ?? [];
  var failed = false;
  for (final raw in items) {
    final item = Map<String, dynamic>.from(raw as Map);
    final verified = item['verified'] as bool? ?? false;
    final lat = item['latitude'];
    final lng = item['longitude'];
    if (verified != true) {
      stderr.writeln('[$path] Unverified place "${item['name']}": verified must be true in production.');
      failed = true;
      continue;
    }
    if (lat == null || lng == null) {
      stderr.writeln('[$path] Verified place "${item['name']}" missing coordinates.');
      failed = true;
    }
  }
  return failed;
}

bool _checkTricycleZones() {
  final path = 'assets/data/transport/tricycle_zones.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Missing $path');
    return true;
  }
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final zones = root['zones'] as List<dynamic>? ?? [];
  var failed = false;
  for (final raw in zones) {
    final zone = Map<String, dynamic>.from(raw as Map);
    final verified = zone['verified'] as bool? ?? false;
    if (verified != true) {
      stderr.writeln('[tricycle] Unverified zone "${zone['zone_name']}": verified must be true.');
      failed = true;
    }
    final geom = zone['polygon_geojson'];
    if (geom == null) {
      stderr.writeln('[tricycle] Zone "${zone['zone_name']}" missing polygon_geojson.');
      failed = true;
    }
  }
  return failed;
}
