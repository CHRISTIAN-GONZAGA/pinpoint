import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// A geographic coordinate with optional address label.
class MapLocation extends Equatable {
  const MapLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.accuracyMeters,
  });

  factory MapLocation.fromLatLng(LatLng point, {String? label, double? accuracy}) {
    return MapLocation(
      latitude: point.latitude,
      longitude: point.longitude,
      label: label,
      accuracyMeters: accuracy,
    );
  }

  final double latitude;
  final double longitude;
  final String? label;
  final double? accuracyMeters;

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  List<Object?> get props => [latitude, longitude, label];
}

/// Jeepney route stop along an official route.
class RouteStop extends Equatable {
  const RouteStop({
    required this.stopId,
    required this.routeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      stopId: json['stop_id'] as int,
      routeId: json['route_id'] as int,
      name: json['stop_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      order: json['stop_order'] as int,
    );
  }

  final int stopId;
  final int routeId;
  final String name;
  final double latitude;
  final double longitude;
  final int order;

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  List<Object?> get props => [stopId, routeId, name];
}

/// Official jeepney route (R1–R7).
class JeepneyRoute extends Equatable {
  const JeepneyRoute({
    required this.routeId,
    required this.routeCode,
    required this.routeName,
    required this.colorHex,
    required this.polyline,
    this.description,
    this.operatingHours,
    this.stops = const [],
  });

  factory JeepneyRoute.fromJson(Map<String, dynamic> json) {
    final geojson = _readGeoJsonMap(json['geojson']);
    final geometry = geojson['geometry'] as Map<String, dynamic>;
    final coordinates = (geometry['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    return JeepneyRoute(
      routeId: (json['route_id'] as num).toInt(),
      routeCode: json['route_code'] as String,
      routeName: json['route_name'] as String,
      colorHex: json['color'] as String,
      description: json['description'] as String?,
      operatingHours: json['operating_hours'] as String?,
      polyline: coordinates,
      stops: (json['stops'] as List<dynamic>? ?? [])
          .map((s) => RouteStop.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }

  final int routeId;
  final String routeCode;
  final String routeName;
  final String colorHex;
  final String? description;
  final String? operatingHours;
  final List<LatLng> polyline;
  final List<RouteStop> stops;

  @override
  List<Object?> get props => [routeId, routeCode];
}

/// Tricycle service zone polygon.
class TricycleZone extends Equatable {
  const TricycleZone({
    required this.zoneId,
    required this.zoneName,
    required this.polygon,
    required this.baseFare,
    this.notes,
  });

  factory TricycleZone.fromJson(Map<String, dynamic> json) {
    final geojson = _readGeoJsonMap(json['polygon_geojson']);
    final geometry = geojson['geometry'] as Map<String, dynamic>;
    final ring = (geometry['coordinates'] as List).first as List;
    final polygon = ring
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    return TricycleZone(
      zoneId: (json['zone_id'] as num).toInt(),
      zoneName: json['zone_name'] as String,
      polygon: polygon,
      baseFare: (json['base_fare'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  final int zoneId;
  final String zoneName;
  final List<LatLng> polygon;
  final double baseFare;
  final String? notes;

  @override
  List<Object?> get props => [zoneId, zoneName];
}

/// Fare configuration from administrator matrix.
class FareConfig extends Equatable {
  const FareConfig({
    required this.transportType,
    required this.minimumFare,
    required this.succeedingRate,
  });

  factory FareConfig.fromJson(Map<String, dynamic> json) {
    return FareConfig(
      transportType: json['transport_type'] as String,
      minimumFare: (json['minimum_fare'] as num).toDouble(),
      succeedingRate: (json['succeeding_rate'] as num).toDouble(),
    );
  }

  final String transportType;
  final double minimumFare;
  final double succeedingRate;

  double computeFare(double distanceKm) {
    if (distanceKm <= 4) return minimumFare;
    final extraKm = distanceKm - 4;
    return minimumFare + (extraKm * succeedingRate);
  }

  @override
  List<Object?> get props => [transportType, minimumFare];
}

/// Type of segment in a multi-modal journey.
enum RouteStepType { walk, jeepney, tricycle, taxi, transfer }

/// Preferred vehicle mode for route planning.
enum VehicleMode { auto, jeepney, tricycle, taxi }

/// Map pin placement mode for tagging start / destination.
enum MapPinMode { none, origin, destination }

/// Single step in step-by-step navigation.
class RouteStep extends Equatable {
  const RouteStep({
    required this.type,
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.routeCode,
    this.polyline = const [],
    this.segmentColorHex,
  });

  final RouteStepType type;
  final String instruction;
  final double distanceMeters;
  final int durationSeconds;
  final String? routeCode;
  final List<LatLng> polyline;
  final String? segmentColorHex;

  String get durationLabel {
    final minutes = (durationSeconds / 60).ceil();
    return minutes < 1 ? '< 1 min' : '$minutes min';
  }

  @override
  List<Object?> get props => [type, instruction, routeCode];
}

/// Complete generated multi-modal route.
class PlannedRoute extends Equatable {
  const PlannedRoute({
    required this.steps,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.estimatedFare,
    required this.transferCount,
    required this.fullPolyline,
    required this.walkingDistanceMeters,
    this.primaryMode = VehicleMode.jeepney,
    this.isRecommended = false,
    this.warningMessage,
    this.coloredSegments = const [],
  });

  final List<RouteStep> steps;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double estimatedFare;
  final int transferCount;
  final List<LatLng> fullPolyline;
  final double walkingDistanceMeters;
  final VehicleMode primaryMode;
  final bool isRecommended;
  final String? warningMessage;
  final List<ColoredRouteSegment> coloredSegments;

  String get durationLabel {
    final minutes = (totalDurationSeconds / 60).ceil();
    return '$minutes min';
  }

  String get distanceLabel {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${totalDistanceMeters.round()} m';
  }

  @override
  List<Object?> get props =>
      [steps, estimatedFare, totalDurationSeconds, primaryMode, isRecommended];
}

/// A map polyline segment with its transport color.
class ColoredRouteSegment extends Equatable {
  const ColoredRouteSegment({
    required this.type,
    required this.polyline,
    required this.colorHex,
    this.routeCode,
  });

  final RouteStepType type;
  final List<LatLng> polyline;
  final String colorHex;
  final String? routeCode;

  @override
  List<Object?> get props => [type, polyline.length, colorHex];
}

Map<String, dynamic> _readGeoJsonMap(Object? value) {
  if (value is String) {
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }
  return Map<String, dynamic>.from(value as Map);
}
