import 'package:equatable/equatable.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/route_planning_models.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart' as places;

/// Layer visibility toggles for map overlays.
class MapLayerVisibility extends Equatable {
  const MapLayerVisibility({
    this.showJeepneyRoutes = false,
    this.showTricycleZones = false,
    this.showJeepneyStops = true,
    this.showStopLabels = false,
    this.showTransferPoints = true,
    this.showTouristLayer = false,
    this.showEmergency = false,
    this.showHighwayCorridors = false,
  });

  final bool showJeepneyRoutes;
  final bool showTricycleZones;
  final bool showJeepneyStops;
  final bool showStopLabels;
  final bool showTransferPoints;
  final bool showTouristLayer;
  final bool showEmergency;
  final bool showHighwayCorridors;

  /// Zoom-aware visibility for jeepney route lines (≥14).
  bool showJeepneyLinesAtZoom(double zoom) => showJeepneyRoutes && zoom >= 14;

  /// Stop markers visible at ≥15.5.
  bool showStopsAtZoom(double zoom) => showJeepneyStops && zoom >= 15.5;

  /// Stop labels visible at ≥16.5.
  bool showLabelsAtZoom(double zoom) => showStopLabels && zoom >= 16.5;

  MapLayerVisibility copyWith({
    bool? showJeepneyRoutes,
    bool? showTricycleZones,
    bool? showJeepneyStops,
    bool? showStopLabels,
    bool? showTransferPoints,
    bool? showTouristLayer,
    bool? showEmergency,
    bool? showHighwayCorridors,
  }) {
    return MapLayerVisibility(
      showJeepneyRoutes: showJeepneyRoutes ?? this.showJeepneyRoutes,
      showTricycleZones: showTricycleZones ?? this.showTricycleZones,
      showJeepneyStops: showJeepneyStops ?? this.showJeepneyStops,
      showStopLabels: showStopLabels ?? this.showStopLabels,
      showTransferPoints: showTransferPoints ?? this.showTransferPoints,
      showTouristLayer: showTouristLayer ?? this.showTouristLayer,
      showEmergency: showEmergency ?? this.showEmergency,
      showHighwayCorridors: showHighwayCorridors ?? this.showHighwayCorridors,
    );
  }

  @override
  List<Object?> get props => [
        showJeepneyRoutes,
        showTricycleZones,
        showJeepneyStops,
        showStopLabels,
        showTransferPoints,
        showTouristLayer,
        showEmergency,
        showHighwayCorridors,
      ];
}

/// Complete map screen state.
class MapState extends Equatable {
  const MapState({
    this.isLoading = false,
    this.isLocating = false,
    this.isGeneratingRoute = false,
    this.errorMessage,
    this.locationWarning,
    this.transportWarning,
    this.tilesUnavailable = false,
    this.currentLocation,
    this.currentAddress,
    this.destination,
    this.destinationAddress,
    this.jeepneyRoutes = const [],
    this.tricycleZones = const [],
    this.fares = const [],
    this.plannedRoute,
    this.routeOptions = const [],
    this.selectedVehicleMode = VehicleMode.auto,
    this.routePreference = RoutePreference.balanced,
    this.pinMode = MapPinMode.none,
    this.layers = const MapLayerVisibility(),
    this.selectedRoute,
    this.searchResults = const [],
    this.isSearching = false,
    this.mapController,
    this.poiPlaces = const [],
    this.featuredDestinations = const [],
    this.emergencyContacts = const [],
    this.highwayCorridors = const [],
    this.visibleRouteCodes = const {},
    this.roadRoutePolylines = const {},
    this.mapZoom = AppConstants.defaultMapZoom,
    this.previewOptionId,
    this.highlightedStepIndex,
    this.isNavigating = false,
  });

  final bool isLoading;
  final bool isLocating;
  final bool isGeneratingRoute;
  final String? errorMessage;
  final String? locationWarning;
  final String? transportWarning;
  final bool tilesUnavailable;
  final MapLocation? currentLocation;
  final String? currentAddress;
  final MapLocation? destination;
  final String? destinationAddress;
  final List<JeepneyRoute> jeepneyRoutes;
  final List<TricycleZone> tricycleZones;
  final List<FareConfig> fares;
  final PlannedRoute? plannedRoute;
  final List<PlannedRoute> routeOptions;
  final VehicleMode selectedVehicleMode;
  final RoutePreference routePreference;
  final MapPinMode pinMode;
  final MapLayerVisibility layers;
  final JeepneyRoute? selectedRoute;
  final List<MapLocation> searchResults;
  final bool isSearching;
  final MapController? mapController;
  final List<places.Place> poiPlaces;
  final List<FeaturedDestination> featuredDestinations;
  final List<places.EmergencyContact> emergencyContacts;
  final List<List<LatLng>> highwayCorridors;
  final Set<String> visibleRouteCodes;
  final Map<int, List<LatLng>> roadRoutePolylines;
  final double mapZoom;
  final String? previewOptionId;
  final int? highlightedStepIndex;
  final bool isNavigating;

  List<JeepneyRoute> get filteredJeepneyRoutes {
    if (visibleRouteCodes.isEmpty) return const [];
    return jeepneyRoutes
        .where((route) => visibleRouteCodes.contains(route.routeCode))
        .toList();
  }

  bool get canGenerateRoute => currentLocation != null && destination != null;

  LatLng get mapCenter =>
      currentLocation?.latLng ??
      const LatLng(AppConstants.butuanLat, AppConstants.butuanLng);

  MapState copyWith({
    bool? isLoading,
    bool? isLocating,
    bool? isGeneratingRoute,
    String? errorMessage,
    String? locationWarning,
    String? transportWarning,
    bool? tilesUnavailable,
    MapLocation? currentLocation,
    String? currentAddress,
    MapLocation? destination,
    String? destinationAddress,
    List<JeepneyRoute>? jeepneyRoutes,
    List<TricycleZone>? tricycleZones,
    List<FareConfig>? fares,
    PlannedRoute? plannedRoute,
    List<PlannedRoute>? routeOptions,
    VehicleMode? selectedVehicleMode,
    RoutePreference? routePreference,
    MapPinMode? pinMode,
    MapLayerVisibility? layers,
    JeepneyRoute? selectedRoute,
    List<MapLocation>? searchResults,
    bool? isSearching,
    MapController? mapController,
    List<places.Place>? poiPlaces,
    List<FeaturedDestination>? featuredDestinations,
    List<places.EmergencyContact>? emergencyContacts,
    List<List<LatLng>>? highwayCorridors,
    Set<String>? visibleRouteCodes,
    Map<int, List<LatLng>>? roadRoutePolylines,
    double? mapZoom,
    String? previewOptionId,
    int? highlightedStepIndex,
    bool? isNavigating,
    bool clearPreviewOption = false,
    bool clearHighlightedStep = false,
    bool clearError = false,
    bool clearLocationWarning = false,
    bool clearTransportWarning = false,
    bool clearDestination = false,
    bool clearOrigin = false,
    bool clearRoute = false,
    bool clearSelectedRoute = false,
    bool clearRouteOptions = false,
  }) {
    return MapState(
      isLoading: isLoading ?? this.isLoading,
      isLocating: isLocating ?? this.isLocating,
      isGeneratingRoute: isGeneratingRoute ?? this.isGeneratingRoute,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      locationWarning:
          clearLocationWarning ? null : (locationWarning ?? this.locationWarning),
      transportWarning:
          clearTransportWarning ? null : (transportWarning ?? this.transportWarning),
      tilesUnavailable: tilesUnavailable ?? this.tilesUnavailable,
      currentLocation: clearOrigin ? null : (currentLocation ?? this.currentLocation),
      currentAddress: clearOrigin ? null : (currentAddress ?? this.currentAddress),
      destination: clearDestination ? null : (destination ?? this.destination),
      destinationAddress:
          clearDestination ? null : (destinationAddress ?? this.destinationAddress),
      jeepneyRoutes: jeepneyRoutes ?? this.jeepneyRoutes,
      tricycleZones: tricycleZones ?? this.tricycleZones,
      fares: fares ?? this.fares,
      plannedRoute: clearRoute ? null : (plannedRoute ?? this.plannedRoute),
      routeOptions: clearRouteOptions ? const [] : (routeOptions ?? this.routeOptions),
      selectedVehicleMode: selectedVehicleMode ?? this.selectedVehicleMode,
      routePreference: routePreference ?? this.routePreference,
      pinMode: pinMode ?? this.pinMode,
      layers: layers ?? this.layers,
      selectedRoute:
          clearSelectedRoute ? null : (selectedRoute ?? this.selectedRoute),
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      mapController: mapController ?? this.mapController,
      poiPlaces: poiPlaces ?? this.poiPlaces,
      featuredDestinations: featuredDestinations ?? this.featuredDestinations,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      highwayCorridors: highwayCorridors ?? this.highwayCorridors,
      visibleRouteCodes: visibleRouteCodes ?? this.visibleRouteCodes,
      roadRoutePolylines: roadRoutePolylines ?? this.roadRoutePolylines,
      mapZoom: mapZoom ?? this.mapZoom,
      previewOptionId:
          clearPreviewOption ? null : (previewOptionId ?? this.previewOptionId),
      highlightedStepIndex:
          clearHighlightedStep ? null : (highlightedStepIndex ?? this.highlightedStepIndex),
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        currentLocation,
        destination,
        plannedRoute,
        routeOptions.length,
        selectedVehicleMode,
        routePreference,
        pinMode,
        layers,
        jeepneyRoutes.length,
        errorMessage,
        locationWarning,
        transportWarning,
        tilesUnavailable,
        visibleRouteCodes,
        roadRoutePolylines.length,
      ];
}
