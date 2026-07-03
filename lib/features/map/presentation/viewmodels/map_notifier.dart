import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/core/services/analytics_service.dart';
import 'package:pinpoint/core/services/geocoding_service.dart';
import 'package:pinpoint/core/services/jeepney_path_service.dart';
import 'package:pinpoint/core/services/location_service.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/utils/map_camera_utils.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_state.dart';
import 'package:pinpoint/features/routing/domain/route_planner_service.dart';

/// Manages interactive map state, GPS, layers, and route generation.
class MapNotifier extends Notifier<MapState> {
  late final LocationService _location;
  late final GeocodingService _geocoding;
  late final RoutePlannerService _planner;
  late final JeepneyPathService _jeepneyPaths;
  late final RoutingService _routing;
  final _distance = const Distance();

  @override
  MapState build() {
    _location = ref.read(locationServiceProvider);
    _geocoding = ref.read(geocodingServiceProvider);
    _planner = ref.read(routePlannerServiceProvider);
    _jeepneyPaths = ref.read(jeepneyPathServiceProvider);
    _routing = ref.read(routingServiceProvider);
    return MapState(mapController: MapController());
  }

  Future<void> initialize() async {
    state = state.copyWith(
      isLoading: false,
      clearError: true,
      clearTransportWarning: true,
      tilesUnavailable: false,
    );

    unawaited(_loadTransportOverlays());
    unawaited(_primeLocationAccess());
  }

  Future<void> _loadTransportOverlays() async {
    try {
      final highways = await _loadHighwayCorridors();
      final transport = await ref.read(transportRepositoryProvider).loadAllTransportData();
      state = state.copyWith(
        jeepneyRoutes: transport.routes,
        tricycleZones: transport.zones,
        fares: transport.fares,
        highwayCorridors: highways,
        transportWarning: transport.routes.isEmpty
            ? 'Jeepney route lines are unavailable. The map and pins still work.'
            : null,
        clearTransportWarning: transport.routes.isNotEmpty,
      );

      if (!AppConstants.offlineFirstMode) {
        unawaited(_syncTransportFromApi());
      }
    } catch (_) {
      state = state.copyWith(
        transportWarning:
            'Using map without transport overlays. Tap Start/Destination to set pins.',
      );
    }
  }

  Future<void> _syncTransportFromApi() async {
    try {
      final transport =
          await ref.read(transportRepositoryProvider).refreshFromRemote();
      if (transport.routes.isEmpty && transport.zones.isEmpty) return;
      state = state.copyWith(
        jeepneyRoutes: transport.routes.isNotEmpty ? transport.routes : state.jeepneyRoutes,
        tricycleZones: transport.zones.isNotEmpty ? transport.zones : state.tricycleZones,
        fares: transport.fares.isNotEmpty ? transport.fares : state.fares,
        clearTransportWarning: transport.routes.isNotEmpty,
      );
    } catch (_) {}
  }

  Future<void> _primeLocationAccess() async {
    try {
      await _location.requestPermission();
    } catch (_) {
      // Permission dialog declined or GPS off — refreshLocation surfaces a banner.
    }
    await refreshLocation(animate: true);
  }

  void onTileLoadError() {
    if (!state.tilesUnavailable) {
      state = state.copyWith(tilesUnavailable: true);
    }
  }

  Future<void> openLocationSettings() => _location.openRelevantSettings();

  void toggleRouteFilter(String routeCode) {
    final next = Set<String>.from(state.visibleRouteCodes);
    if (next.contains(routeCode)) {
      next.remove(routeCode);
    } else {
      next.add(routeCode);
    }
    state = state.copyWith(
      visibleRouteCodes: next,
      layers: state.layers.copyWith(showJeepneyRoutes: next.isNotEmpty),
    );
    unawaited(_loadRoadPolylinesForVisibleRoutes());
  }

  void showAllRoutes() {
    final codes = state.jeepneyRoutes.map((r) => r.routeCode).toSet();
    state = state.copyWith(
      visibleRouteCodes: codes,
      layers: state.layers.copyWith(showJeepneyRoutes: true),
    );
    unawaited(_loadRoadPolylinesForVisibleRoutes());
  }

  void clearRouteFilters() {
    state = state.copyWith(
      visibleRouteCodes: {},
      layers: state.layers.copyWith(showJeepneyRoutes: false),
      clearSelectedRoute: true,
    );
  }

  Future<void> _loadRoadPolylinesForVisibleRoutes() async {
    final polylines = Map<int, List<LatLng>>.from(state.roadRoutePolylines);
    for (final route in state.filteredJeepneyRoutes) {
      if (polylines.containsKey(route.routeId)) continue;
      polylines[route.routeId] = await _jeepneyPaths.roadPolylineForRoute(route);
      state = state.copyWith(roadRoutePolylines: Map.from(polylines));
    }
  }

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

      state = state.copyWith(
        isLocating: false,
        currentLocation: location,
        currentAddress:
            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
        clearLocationWarning: true,
      );

      if (animate) {
        MapCameraUtils.moveTo(
          state.mapController,
          location.latLng,
          zoom: state.mapController?.camera.zoom ?? AppConstants.defaultMapZoom,
        );
      }

      final address = await _geocoding.reverseGeocode(location.latLng);
      state = state.copyWith(
        currentLocation: location.copyWith(label: address),
        currentAddress: address,
      );
      await _loadPoiData();
    } catch (e) {
      state = state.copyWith(
        isLocating: false,
        locationWarning: _locationMessage(e),
      );
    }
  }

  void setPinMode(MapPinMode mode) {
    state = state.copyWith(pinMode: mode);
  }

  void updateMapZoom(double zoom) {
    if ((state.mapZoom - zoom).abs() < 0.05) return;
    final autoLabels = zoom >= 16.5;
    state = state.copyWith(
      mapZoom: zoom,
      layers: autoLabels && !state.layers.showStopLabels
          ? state.layers.copyWith(showStopLabels: true)
          : state.layers,
    );
  }

  void resetMapRotation() {
    final controller = state.mapController;
    if (controller == null) return;
    controller.rotate(0);
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

  /// Returns context data for the tap menu. Caller shows [MapContextSheet].
  Future<({LatLng snapped, String address, String? nearestStop, double? nearestM})>
      prepareMapContext(LatLng point) async {
    final snapped = await _routing.snapToNearestRoad(point);
    final address = await _geocoding.reverseGeocode(snapped);
    final nearest = _nearestStop(snapped);
    return (
      snapped: snapped,
      address: address,
      nearestStop: nearest?.name,
      nearestM: nearest != null ? _distance.as(LengthUnit.Meter, snapped, nearest.latLng) : null,
    );
  }

  Future<void> setOriginFromContext(LatLng point) => setOriginFromTap(point);

  Future<void> setDestinationFromContext(LatLng point) => setDestinationFromTap(point);

  Future<void> exploreNearbyAt(LatLng point) async {
    state = state.copyWith(
      layers: state.layers.copyWith(showTouristLayer: true, showJeepneyStops: true),
    );
    MapCameraUtils.moveTo(state.mapController, point, zoom: 16);
    final address = await _geocoding.reverseGeocode(point);
    state = state.copyWith(
      currentLocation: MapLocation.fromLatLng(point, label: address),
      currentAddress: address,
    );
    await _loadPoiData();
  }

  List<MapNearbyItemData> buildNearbyItems(LatLng point) {
    final items = <MapNearbyItemData>[];
    final stop = _nearestStop(point);
    if (stop != null) {
      final m = _distance.as(LengthUnit.Meter, point, stop.latLng).round();
      items.add(MapNearbyItemData(
        kind: 'stop',
        label: stop.name,
        subtitle: '$m m away',
      ));
    }

    TricycleZone? zone;
    for (final z in state.tricycleZones) {
      if (_pointInPolygon(point, z.polygon)) {
        zone = z;
        break;
      }
    }
    if (zone != null) {
      items.add(MapNearbyItemData(
        kind: 'tricycle',
        label: zone.zoneName,
        subtitle: 'Tricycle service area',
      ));
    }

    for (final place in state.poiPlaces.take(3)) {
      final m = _distance.as(LengthUnit.Meter, point, place.latLng).round();
      if (m <= 2000) {
        items.add(MapNearbyItemData(
          kind: place.category ?? place.placeType,
          label: place.name,
          subtitle: '$m m · ${place.category ?? place.placeType}',
        ));
      }
    }
    return items;
  }

  RouteStop? _nearestStop(LatLng point) {
    RouteStop? nearest;
    var best = double.infinity;
    for (final route in state.jeepneyRoutes) {
      for (final stop in route.stops) {
        final d = _distance.as(LengthUnit.Meter, point, stop.latLng);
        if (d < best) {
          best = d;
          nearest = stop;
        }
      }
    }
    return nearest;
  }

  bool isTransferStop(RouteStop stop) {
    var routes = 0;
    for (final route in state.jeepneyRoutes) {
      if (route.stops.any((s) => s.stopId == stop.stopId || s.name == stop.name)) {
        routes++;
      }
    }
    return routes > 1;
  }

  bool isTerminalStop(RouteStop stop) =>
      stop.name.toLowerCase().contains('terminal');

  Future<void> updateOriginDrag(LatLng point) async {
    state = state.copyWith(
      currentLocation: MapLocation.fromLatLng(point, label: state.currentAddress),
    );
  }

  Future<void> finishOriginDrag() async {
    final point = state.currentLocation?.latLng;
    if (point != null) await setOriginFromTap(point);
  }

  Future<void> updateDestinationDrag(LatLng point) async {
    state = state.copyWith(
      destination: MapLocation.fromLatLng(point, label: state.destinationAddress),
    );
  }

  Future<void> finishDestinationDrag() async {
    final point = state.destination?.latLng;
    if (point != null) await setDestinationFromTap(point);
  }

  void previewRouteOption(PlannedRoute? option) {
    if (option == null || option.primaryMode == state.plannedRoute?.primaryMode) {
      state = state.copyWith(clearPreviewVehicleMode: true);
      if (state.plannedRoute != null) _fitRoute(state.plannedRoute!);
      return;
    }
    state = state.copyWith(previewVehicleMode: option.primaryMode);
    _fitRoute(option);
  }

  void focusRouteStep(int index) {
    final route = state.plannedRoute;
    if (route == null || index < 0 || index >= route.steps.length) return;
    final step = route.steps[index];
    state = state.copyWith(highlightedStepIndex: index);
    if (step.polyline.isNotEmpty) {
      MapCameraUtils.fitStep(state.mapController, step.polyline);
    }
  }

  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
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

  Future<void> setOriginFromTap(LatLng point) async {
    final snapped = await _routing.snapToNearestRoad(point);
    final address = await _geocoding.reverseGeocode(snapped);
    state = state.copyWith(
      currentLocation: MapLocation.fromLatLng(snapped, label: address),
      currentAddress: address,
      clearRoute: true,
      clearRouteOptions: true,
      clearLocationWarning: true,
    );
    MapCameraUtils.moveTo(state.mapController, snapped, zoom: 15.5);
    _fitEndpoints();
    await _loadPoiData();
    await _maybeAutoGenerateRoute();
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
    final snapped = await _routing.snapToNearestRoad(location.latLng);
    final address =
        location.label ?? await _geocoding.reverseGeocode(snapped);
    state = state.copyWith(
      destination: MapLocation.fromLatLng(snapped, label: address),
      destinationAddress: address,
      searchResults: [],
      isSearching: false,
      clearRoute: true,
      clearRouteOptions: true,
    );
    MapCameraUtils.moveTo(state.mapController, snapped, zoom: 15.5);
    _fitEndpoints();
    await _maybeAutoGenerateRoute();
  }

  Future<void> setDestinationFromTap(LatLng point) async {
    await selectDestination(MapLocation.fromLatLng(point));
  }

  Future<void> _maybeAutoGenerateRoute() async {
    if (!state.canGenerateRoute || state.isGeneratingRoute) return;
    await generateRoute();
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
    state = state.copyWith(
      plannedRoute: option,
      clearPreviewVehicleMode: true,
      clearHighlightedStep: true,
    );
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
      MapCameraUtils.fitPoints(state.mapController, points);
    }
  }

  void _fitEndpoints() {
    final points = <LatLng>[
      if (state.currentLocation != null) state.currentLocation!.latLng,
      if (state.destination != null) state.destination!.latLng,
    ];
    if (points.length >= 2) {
      MapCameraUtils.fitPoints(state.mapController, points);
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

  String _locationMessage(Object error) {
    if (error is AppException) return error.message;
    if (error is TimeoutException) {
      return 'GPS signal is weak. Move near a window or outdoors, then tap the location button.';
    }
    if (error is LocationServiceDisabledException) {
      return 'GPS is off on your phone. Turn on Location in system settings.';
    }
    return _message(error);
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

/// Lightweight nearby item for long-press sheet.
class MapNearbyItemData {
  const MapNearbyItemData({
    required this.kind,
    required this.label,
    required this.subtitle,
  });

  final String kind;
  final String label;
  final String subtitle;
}
