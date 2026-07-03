import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

/// Finds optimal transfer points between two jeepney routes.
///
/// Disambiguates R1/R2 shared hub names (Libertad, JAQNO, etc.) by requiring
/// stops to belong to their respective route geometries — never matches by name alone.
class TransferOptimizer {
  TransferOptimizer(this._geometry);

  final RoutingGeometry _geometry;

  static const maxTransferWalkMeters = 600.0;
  static const sharedHubMaxMeters = 150.0;

  TransferPoint? bestTransfer(JeepneyRoute originRoute, JeepneyRoute destRoute) {
    if (originRoute.routeId == destRoute.routeId) return null;

    final originStops = originRoute.verifiedStops;
    final destStops = destRoute.verifiedStops;
    if (originStops.isEmpty || destStops.isEmpty) return null;

    RouteStop? bestOrigin;
    RouteStop? bestDest;
    var bestWalk = double.infinity;

    for (final oStop in originStops) {
      final oOnCorridor = _geometry.distancePointToPolylineMeters(oStop.latLng, originRoute.polyline);
      if (oOnCorridor > 400) continue;

      for (final dStop in destStops) {
        final dOnCorridor = _geometry.distancePointToPolylineMeters(dStop.latLng, destRoute.polyline);
        if (dOnCorridor > 400) continue;

        final walk = _geometry.distanceMeters(oStop.latLng, dStop.latLng);

        // Same display name on different routes (R1/R2 overlap) — only allow if
        // stops are physically co-located (shared hub), not name coincidence.
        if (oStop.name == dStop.name && oStop.stopKey != dStop.stopKey) {
          if (walk > sharedHubMaxMeters) continue;
        }

        if (walk < bestWalk) {
          bestWalk = walk;
          bestOrigin = oStop;
          bestDest = dStop;
        }
      }
    }

    if (bestOrigin == null || bestDest == null) return null;
    if (bestWalk > maxTransferWalkMeters) return null;

    return TransferPoint(
      originStop: bestOrigin,
      destStop: bestDest,
      walkMeters: bestWalk,
      originRouteCode: originRoute.routeCode,
      destRouteCode: destRoute.routeCode,
    );
  }
}

class TransferPoint {
  const TransferPoint({
    required this.originStop,
    required this.destStop,
    required this.walkMeters,
    required this.originRouteCode,
    required this.destRouteCode,
  });

  final RouteStop originStop;
  final RouteStop destStop;
  final double walkMeters;
  final String originRouteCode;
  final String destRouteCode;

  LatLng get midpoint => LatLng(
        (originStop.latitude + destStop.latitude) / 2,
        (originStop.longitude + destStop.longitude) / 2,
      );
}
