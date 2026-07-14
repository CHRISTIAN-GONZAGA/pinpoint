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
    this.verified = true,
    this.stopKey,
    this.source,
    this.description,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json, {int? routeId, int? order}) {
    final lat = json['lat'] ?? json['latitude'];
    final lng = json['lng'] ?? json['longitude'];
    return RouteStop(
      stopId: (json['stop_id'] as num?)?.toInt() ?? order ?? 0,
      routeId: (json['route_id'] as num?)?.toInt() ?? routeId ?? 0,
      name: (json['name'] ?? json['stop_name']) as String,
      latitude: lat == null ? 0 : (lat as num).toDouble(),
      longitude: lng == null ? 0 : (lng as num).toDouble(),
      order: (json['stop_order'] as num?)?.toInt() ?? order ?? 0,
      verified: json['verified'] as bool? ?? true,
      stopKey: json['id'] as String?,
      source: json['source'] as String?,
      description: json['description'] as String?,
    );
  }

  final int stopId;
  final int routeId;
  final String name;
  final double latitude;
  final double longitude;
  final int order;
  final bool verified;
  final String? stopKey;
  final String? source;
  final String? description;

  LatLng get latLng => LatLng(latitude, longitude);

  bool get hasCoordinates => latitude != 0 || longitude != 0;

  Map<String, dynamic> toJson() => {
        'stop_id': stopId,
        'route_id': routeId,
        'name': name,
        'stop_name': name,
        'lat': latitude,
        'lng': longitude,
        'latitude': latitude,
        'longitude': longitude,
        'stop_order': order,
        'verified': verified,
        if (stopKey != null) 'id': stopKey,
        if (description != null) 'description': description,
      };

  @override
  List<Object?> get props => [stopId, routeId, name, stopKey];
}

/// Official transit corridor route (jeepney and other vehicle types).
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
    this.bidirectional = true,
    this.streetSegments = const [],
    this.vehicleType = 'jeepney',
    this.baseFare,
    this.additionalFare,
    this.activeStatus = true,
  });

  factory JeepneyRoute.fromJson(Map<String, dynamic> json) {
    final routeId = (json['route_id'] as num?)?.toInt() ?? 0;
    final routeCode = (json['code'] ?? json['route_code']) as String;
    final routeName = (json['name'] ?? json['route_name']) as String;
    final colorHex = json['color'] as String;

    List<LatLng> polyline;
    if (json['corridor_geojson'] != null) {
      final geom = Map<String, dynamic>.from(
        (json['corridor_geojson'] as Map)['coordinates'] != null
            ? json['corridor_geojson'] as Map
            : json['corridor_geojson'] as Map,
      );
      final coordinates = (geom['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      polyline = coordinates;
    } else {
      final geojson = _readGeoJsonMap(json['geojson']);
      final geometry = geojson['geometry'] as Map<String, dynamic>;
      final coordinates = (geometry['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      polyline = coordinates;
    }

    final rawStops = json['ordered_stops'] as List<dynamic>? ?? json['stops'] as List<dynamic>? ?? [];
    final stops = <RouteStop>[];
    for (var i = 0; i < rawStops.length; i++) {
      final stopJson = Map<String, dynamic>.from(rawStops[i] as Map);
      stops.add(RouteStop.fromJson(stopJson, routeId: routeId, order: i + 1));
    }

    return JeepneyRoute(
      routeId: routeId,
      routeCode: routeCode,
      routeName: routeName,
      colorHex: colorHex,
      description: json['description'] as String?,
      operatingHours: json['operating_hours'] as String?,
      polyline: polyline,
      stops: stops,
      bidirectional: json['bidirectional'] as bool? ?? true,
      streetSegments: (json['street_segments'] as List<dynamic>? ?? [])
          .map((s) => s as String)
          .toList(),
      vehicleType: (json['vehicle_type'] as String?)?.toLowerCase() ?? 'jeepney',
      baseFare: (json['base_fare'] as num?)?.toDouble(),
      additionalFare: (json['additional_fare'] as num?)?.toDouble(),
      activeStatus: json['active_status'] as bool? ?? true,
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
  final bool bidirectional;
  final List<String> streetSegments;
  final String vehicleType;
  final double? baseFare;
  final double? additionalFare;
  final bool activeStatus;

  /// Stops with verified coordinates — only these may be used for routing pins.
  List<RouteStop> get verifiedStops =>
      stops.where((s) => s.verified && s.hasCoordinates).toList();

  bool get isRoutable => activeStatus && verifiedStops.length >= 2 && polyline.length >= 2;

  bool get isCorridorVehicle => const {
        'jeepney',
        'modern_jeepney',
        'bus',
        'van',
        'tricycle',
        'taxi',
      }.contains(vehicleType);

  bool get isOnDemandTaxi => vehicleType == 'taxi';

  JeepneyRoute copyWith({
    int? routeId,
    String? routeCode,
    String? routeName,
    String? colorHex,
    String? description,
    String? operatingHours,
    List<LatLng>? polyline,
    List<RouteStop>? stops,
    bool? bidirectional,
    List<String>? streetSegments,
    String? vehicleType,
    double? baseFare,
    double? additionalFare,
    bool? activeStatus,
  }) {
    return JeepneyRoute(
      routeId: routeId ?? this.routeId,
      routeCode: routeCode ?? this.routeCode,
      routeName: routeName ?? this.routeName,
      colorHex: colorHex ?? this.colorHex,
      description: description ?? this.description,
      operatingHours: operatingHours ?? this.operatingHours,
      polyline: polyline ?? this.polyline,
      stops: stops ?? this.stops,
      bidirectional: bidirectional ?? this.bidirectional,
      streetSegments: streetSegments ?? this.streetSegments,
      vehicleType: vehicleType ?? this.vehicleType,
      baseFare: baseFare ?? this.baseFare,
      additionalFare: additionalFare ?? this.additionalFare,
      activeStatus: activeStatus ?? this.activeStatus,
    );
  }

  @override
  List<Object?> get props => [routeId, routeCode, vehicleType, activeStatus];
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
enum RouteStepType {
  walk,
  jeepney,
  modernJeepney,
  bus,
  van,
  tricycle,
  taxi,
  transfer,
}

/// Preferred vehicle mode for route planning.
enum VehicleMode {
  auto,
  walk,
  jeepney,
  modernJeepney,
  bus,
  van,
  tricycle,
  taxi,
}

/// Maps persisted vehicle_type strings to step / mode enums.
abstract final class VehicleTypeMapping {
  static RouteStepType stepType(String vehicleType) => switch (vehicleType) {
        'modern_jeepney' => RouteStepType.modernJeepney,
        'bus' => RouteStepType.bus,
        'van' => RouteStepType.van,
        'tricycle' => RouteStepType.tricycle,
        'taxi' => RouteStepType.taxi,
        _ => RouteStepType.jeepney,
      };

  static VehicleMode vehicleMode(String vehicleType) => switch (vehicleType) {
        'modern_jeepney' => VehicleMode.modernJeepney,
        'bus' => VehicleMode.bus,
        'van' => VehicleMode.van,
        'tricycle' => VehicleMode.tricycle,
        'taxi' => VehicleMode.taxi,
        _ => VehicleMode.jeepney,
      };

  static String displayName(String vehicleType) => switch (vehicleType) {
        'modern_jeepney' => 'Modern Jeepney',
        'bus' => 'Bus',
        'van' => 'Van',
        'tricycle' => 'Tricycle',
        'taxi' => 'Taxi',
        _ => 'Jeepney',
      };

  static bool isCorridorStep(RouteStepType type) =>
      type == RouteStepType.jeepney ||
      type == RouteStepType.modernJeepney ||
      type == RouteStepType.bus ||
      type == RouteStepType.van ||
      type == RouteStepType.tricycle ||
      type == RouteStepType.taxi;
}

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
    required this.optionId,
    this.primaryMode = VehicleMode.jeepney,
    this.isRecommended = false,
    this.warningMessage,
    this.coloredSegments = const [],
    this.summaryTitle,
    this.explanation,
    this.stopCount = 0,
    this.rankScore,
  });

  final List<RouteStep> steps;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double estimatedFare;
  final int transferCount;
  final List<LatLng> fullPolyline;
  final double walkingDistanceMeters;
  final String optionId;
  final VehicleMode primaryMode;
  final bool isRecommended;
  final String? warningMessage;
  final List<ColoredRouteSegment> coloredSegments;
  final String? summaryTitle;
  final String? explanation;
  final int stopCount;
  final double? rankScore;

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

  String get arrivalLabel {
    final arrival = DateTime.now().add(Duration(seconds: totalDurationSeconds));
    final hour = arrival.hour > 12 ? arrival.hour - 12 : (arrival.hour == 0 ? 12 : arrival.hour);
    final amPm = arrival.hour >= 12 ? 'PM' : 'AM';
    final min = arrival.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }

  PlannedRoute copyWith({
    bool? isRecommended,
    String? warningMessage,
    String? explanation,
    double? rankScore,
  }) {
    return PlannedRoute(
      steps: steps,
      totalDistanceMeters: totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds,
      estimatedFare: estimatedFare,
      transferCount: transferCount,
      fullPolyline: fullPolyline,
      walkingDistanceMeters: walkingDistanceMeters,
      optionId: optionId,
      primaryMode: primaryMode,
      isRecommended: isRecommended ?? this.isRecommended,
      warningMessage: warningMessage ?? this.warningMessage,
      coloredSegments: coloredSegments,
      summaryTitle: summaryTitle,
      explanation: explanation ?? this.explanation,
      stopCount: stopCount,
      rankScore: rankScore ?? this.rankScore,
    );
  }

  @override
  List<Object?> get props =>
      [optionId, steps, estimatedFare, totalDurationSeconds, primaryMode, isRecommended];
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
