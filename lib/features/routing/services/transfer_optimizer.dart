import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/services/routing_geometry.dart';

/// Finds optimal transfer points between two jeepney routes.
class TransferOptimizer {
  TransferOptimizer(this._geometry);

  final RoutingGeometry _geometry;

  static const maxTransferWalkMeters = 600.0;

  TransferPoint? bestTransfer(JeepneyRoute originRoute, JeepneyRoute destRoute) {
    RouteStop? bestOrigin;
    RouteStop? bestDest;
    var bestWalk = double.infinity;

    for (final oStop in originRoute.stops) {
      for (final dStop in destRoute.stops) {
        final walk = _geometry.distanceMeters(oStop.latLng, dStop.latLng);
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
    );
  }
}

class TransferPoint {
  const TransferPoint({
    required this.originStop,
    required this.destStop,
    required this.walkMeters,
  });

  final RouteStop originStop;
  final RouteStop destStop;
  final double walkMeters;

  LatLng get midpoint => LatLng(
        (originStop.latitude + destStop.latitude) / 2,
        (originStop.longitude + destStop.longitude) / 2,
      );
}
