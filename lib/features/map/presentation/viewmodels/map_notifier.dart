import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/core/services/analytics_service.dart';
import 'package:pinpoint/core/services/geocoding_service.dart';
import 'package:pinpoint/core/services/location_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_state.dart';
import 'package:pinpoint/features/routing/domain/route_planner_service.dart';

/// Manages interactive map state, GPS, layers, and route generation.
class MapNotifier extends Notifier<MapState> {
  late final LocationService _location;
  late final GeocodingService _geocoding;
  late final RoutePlannerService _planner;

  @override
  MapState build() {
    _location = ref.read(locationServiceProvider);
    _geocoding = ref.read(geocodingServiceProvider);
    _planner = ref.read(routePlannerServiceProvider);
    return MapState(mapController: MapController());
  }

  Future<void> initialize() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearLocationWarning: true,
      clearTransportWarning: true,
      tilesUnavailable: false,
    );
    try {
      final transport = await ref.read(transportRepositoryProvider).loadAllTransportData();
      final highways = await _loadHighwayCorridors();
      state = state.copyWith(
        isLoading: false,
        jeepneyRoutes: transport.routes,
        tricycleZones: transport.zones,
        fares: transport.fares,
        highwayCorridors: highways,
        transportWarning: transport.routes.isEmpty
            ? 'Jeepney route lines are unavailable. The map and pins still work.'
            : null,
        clearTransportWarning: transport.routes.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        jeepneyRoutes: const [],
        tricycleZones: const [],
        fares: const [],
        transportWarning:
            'Using map without transport overlays. Tap Start/Destination to set pins.',
      );
    }

    // Show the map immediately; resolve GPS in the background.
    unawaited(refreshLocation(animate: true));
    unawaited(_loadPoiData());
  }

  void onTileLoadError() {
    if (!state.tilesUnavailable) {
      state = state.copyWith(tilesUnavailable: true);
    }
  }

  Future<void> openLocationSettings() => _location.openSettings();

  Future<List<List<LatLng>>> _loadHighwayCorridors() async {
    try {
      final data = await AssetLoader.loadJson(AssetPaths.nationalHighways);
      return (data['corridors'] as List<dynamic>? ?? [])
          .map((corridor) {
            final ring = (corridor as Map<String, dynamic>)['polyline'] as List<dynamic>;
            return ring
                .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshLocation({bool animate = false}) async {
    state = state.copyWith(isLocating: true, clearLocationWarning: true);
    try {
      final location = await _location.getCurrentLocation();
      final address = await _geocoding.reverseGeocode(location.latLng);
      state = state.copyWith(
        isLocating: false,
        currentLocation: location.copyWith(label: address),
        currentAddress: address,
      );
      if (animate) {
        state.mapController?.move(
          location.latLng,
          state.mapController?.camera.zoom ?? AppConstants.defaultMapZoom,
        );
      }
      await _loadPoiData();
    } catch (e) {
      state = state.copyWith(
        isLocating: false,
        locationWarning: _message(e),
      );
    }
  }

  void setPinMode(MapPinMode mode) {
    state = state.copyWith(pinMode: mode);
  }

  Future<void> handleMapTap(LatLng point) async {
    if (state.pinMode == MapPinMode.origin) {
      await setOriginFromTap(point);
      state = state.copyWith(pinMode: MapPinMode.none);
      return;
    }
    if (state.pinMode == MapPinMode.destination) {
      await setDestinationFromTap(point);
      state = state.copyWith(pinMode: MapPinMode.none);
      return;
    }
    if (state.selectedRoute != null) {
      selectJeepneyRoute(null);
    }
  }

  Future<void> setOriginFromTap(LatLng point) async {
    final address = await _geocoding.reverseGeocode(point);
    state = state.copyWith(
      currentLocation: MapLocation.fromLatLng(point, label: address),
      currentAddress: address,
      clearRoute: true,
      clearRouteOptions: true,
    );
    state.mapController?.move(point, state.mapController?.camera.zoom ?? 15);
    await _loadPoiData();
  }

  Future<void> searchPlaces(String query) async {
    if (query.trim().length < 2) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }
    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final results = await _geocoding.searchPlaces(query);
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (e) {
      state = state.copyWith(isSearching: false, errorMessage: _message(e));
    }
  }

  void clearSearch() {
    state = state.copyWith(searchResults: [], isSearching: false);
  }

  Future<void> selectDestination(MapLocation location) async {
    final address =
        location.label ?? await _geocoding.reverseGeocode(location.latLng);
    state = state.copyWith(
      destination: location.copyWith(label: address),
      destinationAddress: address,
      searchResults: [],
      isSearching: false,
      clearRoute: true,
      clearRouteOptions: true,
    );
    state.mapController?.move(location.latLng, 15);
  }

  Future<void> setDestinationFromTap(LatLng point) async {
    await selectDestination(MapLocation.fromLatLng(point));
  }

  Future<void> swapEndpoints() async {
    final origin = state.currentLocation;
    final dest = state.destination;
    if (origin == null || dest == null) return;
    state = state.copyWith(
      currentLocation: dest.copyWith(label: state.destinationAddress),
      currentAddress: state.destinationAddress,
      destination: origin.copyWith(label: state.currentAddress),
      destinationAddress: state.currentAddress,
      clearRoute: true,
      clearRouteOptions: true,
    );
    state.mapController?.move(dest.latLng, state.mapController?.camera.zoom ?? 15);
  }

  void setVehicleMode(VehicleMode mode) {
    state = state.copyWith(selectedVehicleMode: mode, clearRoute: true, clearRouteOptions: true);
    if (state.canGenerateRoute) {
      generateRoute();
    }
  }

  void selectRouteOption(PlannedRoute option) {
    state = state.copyWith(plannedRoute: option);
    _fitRoute(option);
  }

  void toggleLayer(MapLayerVisibility Function(MapLayerVisibility) update) {
    state = state.copyWith(layers: update(state.layers));
  }

  void selectJeepneyRoute(JeepneyRoute? route) {
    state = state.copyWith(
      selectedRoute: route,
      clearSelectedRoute: route == null,
    );
  }

  Future<void> generateRoute() async {
    final origin = state.currentLocation;
    final destination = state.destination;
    if (origin == null || destination == null) {
      state = state.copyWith(
        errorMessage: 'Tag your start point and destination on the map first.',
      );
      return;
    }
    state = state.copyWith(
      isGeneratingRoute: true,
      clearError: true,
      clearRoute: true,
      clearRouteOptions: true,
    );
    try {
      final options = await _planner.planRouteOptions(
        origin: origin,
        destination: destination,
        jeepneyRoutes: state.jeepneyRoutes,
        tricycleZones: state.tricycleZones,
        fares: state.fares,
        preferredMode: state.selectedVehicleMode,
      );
      final selected = options.first;
      state = state.copyWith(
        isGeneratingRoute: false,
        plannedRoute: selected,
        routeOptions: options,
      );
      await ref.read(routeCacheServiceProvider).saveRoute(
            route: selected,
            originLabel: state.currentAddress ?? 'Start',
            destinationLabel: state.destinationAddress ?? 'Destination',
          );
      ref.read(analyticsServiceProvider).track(
        'route_generated',
        metadata: {
          'mode': selected.primaryMode.name,
          'distance_m': selected.totalDistanceMeters.round(),
          'fare': selected.estimatedFare,
          'transfers': selected.transferCount,
        },
      );
      _fitRoute(selected);
    } catch (e) {
      state = state.copyWith(isGeneratingRoute: false, errorMessage: _message(e));
    }
  }

  void _fitRoute(PlannedRoute route) {
    final coords = route.coloredSegments
        .expand((segment) => segment.polyline)
        .toList();
    final points = coords.isNotEmpty ? coords : route.fullPolyline;
    if (points.isNotEmpty) {
      state.mapController?.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(56),
        ),
      );
    }
  }

  void clearRoute() {
    state = state.copyWith(clearRoute: true, clearRouteOptions: true);
  }

  void clearDestination() {
    state = state.copyWith(clearDestination: true, clearRoute: true, clearRouteOptions: true);
  }

  Future<void> _loadPoiData() async {
    final location = state.currentLocation;
    if (location == null) return;
    try {
      final placesRepo = ref.read(placesRepositoryProvider);
      final nearby = await placesRepo.getNearby(
        lat: location.latitude,
        lng: location.longitude,
        radiusKm: 8,
      );
      final emergency = await placesRepo.getEmergencyContacts();
      state = state.copyWith(poiPlaces: nearby, emergencyContacts: emergency);
    } catch (_) {}
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.contains('AppException:')) {
      return text.replaceFirst('AppException: ', '');
    }
    return 'Something went wrong. Please try again.';
  }
}

extension on MapLocation {
  MapLocation copyWith({String? label}) {
    return MapLocation(
      latitude: latitude,
      longitude: longitude,
      label: label ?? this.label,
      accuracyMeters: accuracyMeters,
    );
  }
}

final mapNotifierProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

/// Exposes current location for the home dashboard.
final currentLocationProvider = Provider<MapLocation?>((ref) {
  return ref.watch(mapNotifierProvider).currentLocation;
});

final currentAddressProvider = Provider<String?>((ref) {
  return ref.watch(mapNotifierProvider).currentAddress;
});
