import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/app/router.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/core/widgets/loading_shimmer.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_state.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_controls.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_pin_bar.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_route_legend.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_search_bar.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_tile_layer.dart';
import 'package:pinpoint/features/map/presentation/widgets/route_summary_sheet.dart';

/// Full-screen interactive OpenStreetMap with transport layers.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _searchController = TextEditingController();
  var _showLayerPanel = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(mapNotifierProvider.notifier).initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(mapNotifierProvider.select((s) => s.errorMessage), (previous, next) {
      if (next != null && next != previous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      }
    });

    if (mapState.isLoading) {
      return const Scaffold(body: LoadingOverlay(message: 'Loading map...'));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapState.mapController,
            options: MapOptions(
              initialCenter: mapState.mapCenter,
              initialZoom: AppConstants.defaultMapZoom,
              minZoom: 11,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onLongPress: (_, point) {
                ref.read(mapNotifierProvider.notifier).setDestinationFromTap(point);
              },
              onTap: (_, point) {
                ref.read(mapNotifierProvider.notifier).handleMapTap(point);
              },
            ),
            children: [
              PinpointTileLayer(
                isDark: isDark,
                onTileError: (_) =>
                    ref.read(mapNotifierProvider.notifier).onTileLoadError(),
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
              if (mapState.layers.showHighwayCorridors)
                PolylineLayer(
                  polylines: mapState.highwayCorridors.map((corridor) {
                    return Polyline(
                      points: corridor,
                      color: AppColors.danger.withValues(alpha: 0.55),
                      strokeWidth: 3,
                      pattern: StrokePattern.dashed(segments: [12, 8]),
                    );
                  }).toList(),
                ),
              if (mapState.layers.showTricycleZones)
                PolygonLayer(
                  polygons: mapState.tricycleZones.map((zone) {
                    return Polygon(
                      points: zone.polygon,
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderColor: AppColors.warning.withValues(alpha: 0.6),
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
              if (mapState.layers.showJeepneyRoutes)
                PolylineLayer(
                  polylines: mapState.jeepneyRoutes.map((route) {
                    final isSelected = mapState.selectedRoute?.routeId == route.routeId;
                    return Polyline(
                      points: route.polyline,
                      color: colorFromHex(route.colorHex),
                      strokeWidth: isSelected ? 6 : 4,
                    );
                  }).toList(),
                ),
              if (mapState.plannedRoute != null)
                PolylineLayer(
                  polylines: _buildColoredRoutePolylines(mapState.plannedRoute!),
                ),
              MarkerLayer(
                markers: [
                  ..._buildStopMarkers(mapState),
                  ..._buildPoiMarkers(mapState),
                  ..._buildEmergencyMarkers(mapState),
                  if (mapState.currentLocation != null)
                    _locationTagMarker(
                      location: mapState.currentLocation!,
                      label: 'Start',
                      color: Theme.of(context).colorScheme.primary,
                      icon: Icons.trip_origin,
                    ),
                  if (mapState.destination != null)
                    _locationTagMarker(
                      location: mapState.destination!,
                      label: 'Destination',
                      color: AppColors.danger,
                      icon: Icons.place_rounded,
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MapSearchBar(
                    controller: _searchController,
                    onChanged: (q) =>
                        ref.read(mapNotifierProvider.notifier).searchPlaces(q),
                    onClear: () {
                      _searchController.clear();
                      ref.read(mapNotifierProvider.notifier).clearSearch();
                    },
                    isSearching: mapState.isSearching,
                    results: mapState.searchResults,
                    onSelect: (loc) {
                      _searchController.text = loc.label ?? 'Destination';
                      ref.read(mapNotifierProvider.notifier).selectDestination(loc);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const MapPinBar(),
                  if (mapState.pinMode != MapPinMode.none)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        mapState.pinMode == MapPinMode.origin
                            ? 'Tap the map to set your start point'
                            : 'Tap the map to set your destination',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  if (mapState.locationWarning != null)
                    _MapBanner(
                      icon: Icons.location_off_rounded,
                      message: mapState.locationWarning!,
                      actionLabel: 'Settings',
                      onAction: () =>
                          ref.read(mapNotifierProvider.notifier).openLocationSettings(),
                    ),
                  if (mapState.transportWarning != null)
                    _MapBanner(
                      icon: Icons.directions_bus_outlined,
                      message: mapState.transportWarning!,
                      actionLabel: 'Retry',
                      onAction: () =>
                          ref.read(mapNotifierProvider.notifier).initialize(),
                    ),
                  if (mapState.tilesUnavailable)
                    const _MapBanner(
                      icon: Icons.map_outlined,
                      message: 'Map tiles unavailable. Check your internet connection.',
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.md,
            top: MediaQuery.sizeOf(context).height * 0.22,
            child: Column(
              children: [
                MapGlassButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: () {
                    final c = mapState.mapController;
                    c?.move(c.camera.center, c.camera.zoom + 1);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                MapGlassButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onPressed: () {
                    final c = mapState.mapController;
                    c?.move(c.camera.center, c.camera.zoom - 1);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                MapGlassButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter',
                  onPressed: () =>
                      ref.read(mapNotifierProvider.notifier).refreshLocation(animate: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                MapGlassButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Layers',
                  isActive: _showLayerPanel,
                  onPressed: () => setState(() => _showLayerPanel = !_showLayerPanel),
                ),
              ],
            ),
          ),
          if (_showLayerPanel)
            Positioned(
              right: AppSpacing.md,
              top: MediaQuery.sizeOf(context).height * 0.42,
              width: 240,
              child: MapLayerPanel(
                showJeepney: mapState.layers.showJeepneyRoutes,
                showTricycle: mapState.layers.showTricycleZones,
                showTourist: mapState.layers.showTouristLayer,
                showEmergency: mapState.layers.showEmergency,
                showHighway: mapState.layers.showHighwayCorridors,
                onJeepneyChanged: (v) => ref
                    .read(mapNotifierProvider.notifier)
                    .toggleLayer((l) => l.copyWith(showJeepneyRoutes: v)),
                onTricycleChanged: (v) => ref
                    .read(mapNotifierProvider.notifier)
                    .toggleLayer((l) => l.copyWith(showTricycleZones: v)),
                onTouristChanged: (v) => ref
                    .read(mapNotifierProvider.notifier)
                    .toggleLayer((l) => l.copyWith(showTouristLayer: v)),
                onEmergencyChanged: (v) => ref
                    .read(mapNotifierProvider.notifier)
                    .toggleLayer((l) => l.copyWith(showEmergency: v)),
                onHighwayChanged: (v) => ref
                    .read(mapNotifierProvider.notifier)
                    .toggleLayer((l) => l.copyWith(showHighwayCorridors: v)),
                onClose: () => setState(() => _showLayerPanel = false),
              ),
            ),
          if (mapState.selectedRoute != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: JeepneyRouteSheet(
                route: mapState.selectedRoute!,
                onClose: () =>
                    ref.read(mapNotifierProvider.notifier).selectJeepneyRoute(null),
              ),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RouteSummarySheet(
                route: mapState.plannedRoute,
                routeOptions: mapState.routeOptions,
                canGenerate: mapState.canGenerateRoute,
                isGenerating: mapState.isGeneratingRoute,
                originLabel: mapState.currentAddress ?? 'Start',
                destinationLabel: mapState.destinationAddress ?? mapState.destination?.label,
                selectedVehicleMode: mapState.selectedVehicleMode,
                onGenerate: () => ref.read(mapNotifierProvider.notifier).generateRoute(),
                onSelectOption: (option) =>
                    ref.read(mapNotifierProvider.notifier).selectRouteOption(option),
                onVehicleModeChanged: (mode) =>
                    ref.read(mapNotifierProvider.notifier).setVehicleMode(mode),
                onClose: () => ref.read(mapNotifierProvider.notifier).clearRoute(),
              ),
            ),
          if (mapState.plannedRoute != null)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: MediaQuery.sizeOf(context).height * 0.5,
              child: MapRouteLegend(route: mapState.plannedRoute!),
            ),
          if (mapState.isLocating)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Locating...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildStopMarkers(MapState mapState) {
    if (!mapState.layers.showJeepneyRoutes) return [];
    return mapState.jeepneyRoutes.expand((route) {
      return route.stops.map((stop) {
        return Marker(
          point: stop.latLng,
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () {
              ref.read(mapNotifierProvider.notifier).selectJeepneyRoute(route);
            },
            child: Container(
              decoration: BoxDecoration(
                color: colorFromHex(route.colorHex),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.circle, size: 8, color: Colors.white),
            ),
          ),
        );
      });
    }).toList();
  }

  List<Marker> _buildPoiMarkers(MapState mapState) {
    if (!mapState.layers.showTouristLayer) return [];
    return mapState.poiPlaces.map((place) {
      final color = PlaceUtils.colorForCategory(place.category);
      return Marker(
        point: place.latLng,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.placeDetail(place.placeType, place.id)),
          child: Icon(PlaceUtils.iconForCategory(place.category), color: color, size: 28),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEmergencyMarkers(MapState mapState) {
    if (!mapState.layers.showEmergency) return [];
    return mapState.emergencyContacts
        .where((c) => c.latitude != null && c.longitude != null)
        .map((contact) {
      return Marker(
        point: LatLng(contact.latitude!, contact.longitude!),
        width: 32,
        height: 32,
        child: const Icon(Icons.emergency_rounded, color: AppColors.danger, size: 28),
      );
    }).toList();
  }

  List<Polyline> _buildColoredRoutePolylines(PlannedRoute route) {
    if (route.coloredSegments.isNotEmpty) {
      return route.coloredSegments.map((segment) {
        return Polyline(
          points: segment.polyline,
          color: colorFromHex(segment.colorHex),
          strokeWidth: segment.type == RouteStepType.walk ? 4 : 6,
          borderColor: Colors.white,
          borderStrokeWidth: 1.5,
        );
      }).toList();
    }
    return [
      Polyline(
        points: route.fullPolyline,
        color: AppColors.accent,
        strokeWidth: 5,
        borderColor: Colors.white,
        borderStrokeWidth: 2,
      ),
    ];
  }

  Marker _locationTagMarker({
    required MapLocation location,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Marker(
      point: location.latLng,
      width: 120,
      height: 72,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(icon, color: color, size: 36),
        ],
      ),
    );
  }
}

class _MapBanner extends StatelessWidget {
  const _MapBanner({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.95),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
