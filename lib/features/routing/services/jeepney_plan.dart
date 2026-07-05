import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Internal jeepney itinerary before assembly into a [PlannedRoute].
class JeepneyPlan {
  const JeepneyPlan({
    required this.boardRoute,
    required this.boardStop,
    required this.alightStop,
    required this.boardPoint,
    required this.alightPoint,
    required this.walkToBoard,
    required this.walkFromAlight,
    required this.estimatedTotalMeters,
    required this.planId,
    this.jeepneyPolyline = const [],
    this.jeepneyDistanceMeters = 0,
    this.jeepneyDurationSeconds = 0,
    this.transferRoute,
    this.transferOriginStop,
    this.transferDestStop,
    this.transferWalk,
    this.transferWalkMeters = 0,
    this.firstLegPolyline = const [],
    this.firstLegDistanceMeters = 0,
    this.firstLegDurationSeconds = 0,
    this.secondLegPolyline = const [],
    this.secondLegDistanceMeters = 0,
    this.secondLegDurationSeconds = 0,
  });

  final String planId;
  final JeepneyRoute boardRoute;
  final RouteStop boardStop;
  final RouteStop alightStop;
  /// Actual corridor attach / alight coordinates (may differ from stop pins).
  final LatLng boardPoint;
  final LatLng alightPoint;
  final ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) walkToBoard;
  final ({List<LatLng> polyline, double distanceMeters, int durationSeconds}) walkFromAlight;
  final double estimatedTotalMeters;

  final List<LatLng> jeepneyPolyline;
  final double jeepneyDistanceMeters;
  final int jeepneyDurationSeconds;

  final JeepneyRoute? transferRoute;
  final RouteStop? transferOriginStop;
  final RouteStop? transferDestStop;
  final ({List<LatLng> polyline, double distanceMeters, int durationSeconds})? transferWalk;
  final double transferWalkMeters;

  final List<LatLng> firstLegPolyline;
  final double firstLegDistanceMeters;
  final int firstLegDurationSeconds;
  final List<LatLng> secondLegPolyline;
  final double secondLegDistanceMeters;
  final int secondLegDurationSeconds;

  bool get hasTransfer => transferRoute != null;
  int get transferCount => hasTransfer ? 1 : 0;

  String get routeSummary {
    if (hasTransfer) {
      return '${boardRoute.routeCode} → ${transferRoute!.routeCode}';
    }
    return boardRoute.routeCode;
  }
}
