import 'package:equatable/equatable.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart' as places;

/// Layer visibility toggles for map overlays.
class MapLayerVisibility extends Equatable {
  const MapLayerVisibility({
    this.showJeepneyRoutes = true,
    this.showTricycleZones = true,
    this.showTouristLayer = false,
    this.showEmergency = false,
    this.showHighwayCorridors = false,
  });

  final bool showJeepneyRoutes;
  final bool showTricycleZones;
  final bool showTouristLayer;
  final bool showEmergency;
  final bool showHighwayCorridors;

  MapLayerVisibility copyWith({
    bool? showJeepneyRoutes,
    bool? showTricycleZones,
    bool? showTouristLayer,
    bool? showEmergency,
    bool? showHighwayCorridors,
  }) {
    return MapLayerVisibility(
      showJeepneyRoutes: showJeepneyRoutes ?? this.showJeepneyRoutes,
      showTricycleZones: showTricycleZones ?? this.showTricycleZones,
      showTouristLayer: showTouristLayer ?? this.showTouristLayer,
      showEmergency: showEmergency ?? this.showEmergency,
      showHighwayCorridors: showHighwayCorridors ?? this.showHighwayCorridors,
    );
  }

  @override
  List<Object?> get props => [
        showJeepneyRoutes,
        showTricycleZones,
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
    this.pinMode = MapPinMode.none,
    this.layers = const MapLayerVisibility(),
    this.selectedRoute,
    this.searchResults = const [],
    this.isSearching = false,
    this.mapController,
    this.poiPlaces = const [],
    this.emergencyContacts = const [],
    this.highwayCorridors = const [],
  });

  final bool isLoading;
  final bool isLocating;
  final bool isGeneratingRoute;
  final String? errorMessage;
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
  final MapPinMode pinMode;
  final MapLayerVisibility layers;
  final JeepneyRoute? selectedRoute;
  final List<MapLocation> searchResults;
  final bool isSearching;
  final MapController? mapController;
  final List<places.Place> poiPlaces;
  final List<places.EmergencyContact> emergencyContacts;
  final List<List<LatLng>> highwayCorridors;

  bool get canGenerateRoute => currentLocation != null && destination != null;

  LatLng get mapCenter =>
      currentLocation?.latLng ??
      const LatLng(AppConstants.butuanLat, AppConstants.butuanLng);

  MapState copyWith({
    bool? isLoading,
    bool? isLocating,
    bool? isGeneratingRoute,
    String? errorMessage,
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
    MapPinMode? pinMode,
    MapLayerVisibility? layers,
    JeepneyRoute? selectedRoute,
    List<MapLocation>? searchResults,
    bool? isSearching,
    MapController? mapController,
    List<places.Place>? poiPlaces,
    List<places.EmergencyContact>? emergencyContacts,
    List<List<LatLng>>? highwayCorridors,
    bool clearError = false,
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
      pinMode: pinMode ?? this.pinMode,
      layers: layers ?? this.layers,
      selectedRoute:
          clearSelectedRoute ? null : (selectedRoute ?? this.selectedRoute),
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      mapController: mapController ?? this.mapController,
      poiPlaces: poiPlaces ?? this.poiPlaces,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      highwayCorridors: highwayCorridors ?? this.highwayCorridors,
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
        pinMode,
        layers,
        jeepneyRoutes.length,
        errorMessage,
      ];
}
