import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

/// Connects origins/destinations to jeepney corridors via tricycle feeder legs.
class TricycleConnector {
  TricycleConnector(this._geometry);

  final RoutingGeometry _geometry;

  /// Suggest tricycle when walking to the PUJ stop would be this long or more.
  static const feederMinWalkMeters = 320.0;
  static const lastMileWalkMeters = 350.0;
  static const tricycleSpeedMps = 150 / 60;
  static const maxZoneLookupMeters = 3000.0;

  TricycleZone? zoneAt(LatLng point, List<TricycleZone> zones) {
    for (final zone in zones) {
      if (_pointInPolygon(point, zone.polygon)) return zone;
    }
    return null;
  }

  /// Zone at point, or nearest city zone for fare estimation.
  TricycleZone? zoneFor(LatLng point, List<TricycleZone> zones) {
    final inside = zoneAt(point, zones);
    if (inside != null) return inside;

    TricycleZone? nearest;
    var bestDist = double.infinity;
    for (final zone in zones) {
      if (zone.polygon.isEmpty) continue;
      final anchor = _zoneAnchor(zone);
      final d = _geometry.distanceMeters(point, anchor);
      if (d < bestDist) {
        bestDist = d;
        nearest = zone;
      }
    }
    if (nearest != null && bestDist <= maxZoneLookupMeters) return nearest;
    return null;
  }

  LatLng _zoneAnchor(TricycleZone zone) {
    if (zone.polygon.isEmpty) return const LatLng(0, 0);
    var lat = 0.0;
    var lng = 0.0;
    for (final p in zone.polygon) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / zone.polygon.length, lng / zone.polygon.length);
  }

  /// Tricycle from [origin] to jeepney [boardStop] when walking is impractical.
  Future<FeederLeg?> originFeeder({
    required LatLng origin,
    required RouteStop boardStop,
    required List<TricycleZone> zones,
  }) async {
    if (zones.isEmpty) return null;

    final walkDist = _geometry.distanceMeters(origin, boardStop.latLng);
    if (walkDist < feederMinWalkMeters) return null;

    final zone = zoneFor(origin, zones) ?? zoneFor(boardStop.latLng, zones);
    if (zone == null) return null;

    final tri = await _geometry.safeDrivingRoute(
      origin,
      boardStop.latLng,
      speedMps: tricycleSpeedMps,
    );

    // Prefer road-following geometry; still offer feeder on long last-mile even if OSRM fails.
    final followsRoad = tri.polyline.length > 2;
    if (!followsRoad && walkDist < 450) return null;

    return FeederLeg(
      from: origin,
      to: boardStop.latLng,
      toLabel: boardStop.name,
      route: tri,
      zone: zone,
      purpose: FeederPurpose.toJeepneyStop,
    );
  }

  /// Last-mile tricycle from jeepney stop to destination.
  Future<FeederLeg?> destinationFeeder({
    required RouteStop alightStop,
    required LatLng destination,
    required List<TricycleZone> zones,
  }) async {
    if (zones.isEmpty) return null;

    final lastMile = _geometry.distanceMeters(alightStop.latLng, destination);
    if (lastMile <= 30) return null;
    if (lastMile < lastMileWalkMeters) return null;

    final zone = zoneFor(destination, zones) ?? zoneFor(alightStop.latLng, zones);
    if (zone == null) return null;

    final tri = await _geometry.safeDrivingRoute(
      alightStop.latLng,
      destination,
      speedMps: tricycleSpeedMps,
    );

    return FeederLeg(
      from: alightStop.latLng,
      to: destination,
      toLabel: 'destination',
      route: tri,
      zone: zone,
      purpose: FeederPurpose.fromJeepneyStop,
    );
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi + 0.0000001) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

enum FeederPurpose { toJeepneyStop, fromJeepneyStop }

class FeederLeg {
  const FeederLeg({
    required this.from,
    required this.to,
    required this.toLabel,
    required this.route,
    required this.zone,
    required this.purpose,
  });

  final LatLng from;
  final LatLng to;
  final String toLabel;
  final ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) route;
  final TricycleZone zone;
  final FeederPurpose purpose;
}
