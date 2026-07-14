import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

enum ManageRoutesMode {
  browse,
  drawing,
  metadata,
  placingStops,
  editing,
}

/// How the admin paints the corridor on the map.
enum RouteDrawTool {
  /// Tap successive points; each segment snaps to roads between taps.
  pin,
  /// Press and drag along roads; released stroke is matched onto the network.
  brush,
}

class DraftStop {
  const DraftStop({
    required this.name,
    required this.point,
    required this.order,
    this.description,
  });

  final String name;
  final LatLng point;
  final int order;
  final String? description;

  DraftStop copyWith({
    String? name,
    LatLng? point,
    int? order,
    String? description,
  }) {
    return DraftStop(
      name: name ?? this.name,
      point: point ?? this.point,
      order: order ?? this.order,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'name': name,
        'lat': point.latitude,
        'lng': point.longitude,
        'stop_order': order,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

/// Default look & fare hints when assigning a vehicle to a drawn road corridor.
class VehicleRoutePreset {
  const VehicleRoutePreset({
    required this.value,
    required this.label,
    required this.colorHex,
    required this.codePrefix,
    required this.suggestedBaseFare,
    required this.suggestedAdditionalFare,
    required this.hint,
  });

  final String value;
  final String label;
  final String colorHex;
  final String codePrefix;
  final double suggestedBaseFare;
  final double suggestedAdditionalFare;
  final String hint;

  static const all = <VehicleRoutePreset>[
    VehicleRoutePreset(
      value: 'jeepney',
      label: 'Jeepney',
      colorHex: '#E63946',
      codePrefix: 'R',
      suggestedBaseFare: 13,
      suggestedAdditionalFare: 1.8,
      hint: 'Fixed PUJ corridor with regular stops',
    ),
    VehicleRoutePreset(
      value: 'modern_jeepney',
      label: 'Modern Jeepney',
      colorHex: '#FB8500',
      codePrefix: 'MJ',
      suggestedBaseFare: 15,
      suggestedAdditionalFare: 2,
      hint: 'Modern PUJ / PUV corridor',
    ),
    VehicleRoutePreset(
      value: 'bus',
      label: 'Bus',
      colorHex: '#457B9D',
      codePrefix: 'B',
      suggestedBaseFare: 15,
      suggestedAdditionalFare: 2,
      hint: 'City or provincial bus line',
    ),
    VehicleRoutePreset(
      value: 'van',
      label: 'Van',
      colorHex: '#2A9D8F',
      codePrefix: 'V',
      suggestedBaseFare: 20,
      suggestedAdditionalFare: 2.5,
      hint: 'UV Express / van corridor',
    ),
    VehicleRoutePreset(
      value: 'tricycle',
      label: 'Tricycle',
      colorHex: '#0EA5E9',
      codePrefix: 'T',
      suggestedBaseFare: 15,
      suggestedAdditionalFare: 2,
      hint: 'Tricycle line along barangay roads',
    ),
    VehicleRoutePreset(
      value: 'taxi',
      label: 'Taxi',
      colorHex: '#EAB308',
      codePrefix: 'TX',
      suggestedBaseFare: 40,
      suggestedAdditionalFare: 13.5,
      hint: 'Enables citywide taxi; optional drawn corridor',
    ),
  ];

  static VehicleRoutePreset forType(String value) => all.firstWhere(
        (p) => p.value == value,
        orElse: () => all.first,
      );
}

class ManageRoutesState {
  const ManageRoutesState({
    this.routes = const [],
    this.selectedRouteId,
    this.mode = ManageRoutesMode.browse,
    this.drawTool = RouteDrawTool.brush,
    this.waypoints = const [],
    this.corridor = const [],
    this.freehandTrace = const [],
    this.draftStops = const [],
    this.routeCode = '',
    this.routeName = '',
    this.vehicleType = 'jeepney',
    this.colorHex = '#E63946',
    this.baseFare,
    this.additionalFare,
    this.description = '',
    this.activeStatus = true,
    this.isLoading = false,
    this.isSaving = false,
    this.isSnapping = false,
    this.isBrushStrokeActive = false,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  final List<JeepneyRoute> routes;
  final int? selectedRouteId;
  final ManageRoutesMode mode;
  final RouteDrawTool drawTool;
  final List<LatLng> waypoints;
  final List<LatLng> corridor;
  final List<LatLng> freehandTrace;
  final List<DraftStop> draftStops;
  final String routeCode;
  final String routeName;
  final String vehicleType;
  final String colorHex;
  final double? baseFare;
  final double? additionalFare;
  final String description;
  final bool activeStatus;
  final bool isLoading;
  final bool isSaving;
  final bool isSnapping;
  final bool isBrushStrokeActive;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  bool get canDrawPath =>
      mode == ManageRoutesMode.drawing || mode == ManageRoutesMode.editing;

  int get workflowStep => switch (mode) {
        ManageRoutesMode.browse => 0,
        ManageRoutesMode.drawing || ManageRoutesMode.editing => 1,
        ManageRoutesMode.metadata => 2,
        ManageRoutesMode.placingStops => 3,
      };

  JeepneyRoute? get selectedRoute {
    if (selectedRouteId == null) return null;
    for (final route in routes) {
      if (route.routeId == selectedRouteId) return route;
    }
    return null;
  }

  List<JeepneyRoute> get filteredRoutes {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return routes;
    return routes
        .where(
          (r) =>
              r.routeCode.toLowerCase().contains(q) ||
              r.routeName.toLowerCase().contains(q) ||
              r.vehicleType.toLowerCase().contains(q),
        )
        .toList();
  }

  ManageRoutesState copyWith({
    List<JeepneyRoute>? routes,
    int? selectedRouteId,
    bool clearSelection = false,
    ManageRoutesMode? mode,
    RouteDrawTool? drawTool,
    List<LatLng>? waypoints,
    List<LatLng>? corridor,
    List<LatLng>? freehandTrace,
    List<DraftStop>? draftStops,
    String? routeCode,
    String? routeName,
    String? vehicleType,
    String? colorHex,
    double? baseFare,
    bool clearBaseFare = false,
    double? additionalFare,
    bool clearAdditionalFare = false,
    String? description,
    bool? activeStatus,
    bool? isLoading,
    bool? isSaving,
    bool? isSnapping,
    bool? isBrushStrokeActive,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ManageRoutesState(
      routes: routes ?? this.routes,
      selectedRouteId: clearSelection ? null : (selectedRouteId ?? this.selectedRouteId),
      mode: mode ?? this.mode,
      drawTool: drawTool ?? this.drawTool,
      waypoints: waypoints ?? this.waypoints,
      corridor: corridor ?? this.corridor,
      freehandTrace: freehandTrace ?? this.freehandTrace,
      draftStops: draftStops ?? this.draftStops,
      routeCode: routeCode ?? this.routeCode,
      routeName: routeName ?? this.routeName,
      vehicleType: vehicleType ?? this.vehicleType,
      colorHex: colorHex ?? this.colorHex,
      baseFare: clearBaseFare ? null : (baseFare ?? this.baseFare),
      additionalFare: clearAdditionalFare ? null : (additionalFare ?? this.additionalFare),
      description: description ?? this.description,
      activeStatus: activeStatus ?? this.activeStatus,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSnapping: isSnapping ?? this.isSnapping,
      isBrushStrokeActive: isBrushStrokeActive ?? this.isBrushStrokeActive,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
