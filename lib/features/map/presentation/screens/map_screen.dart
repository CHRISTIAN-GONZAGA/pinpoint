import 'dart:math' as math;

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
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/utils/map_camera_helper.dart';
import 'package:pinpoint/features/map/presentation/utils/map_polyline_utils.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_state.dart';
import 'package:pinpoint/features/map/presentation/widgets/featured_destination_sheet.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_context_sheet.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_controls.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_minimal_header.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_tools_sheet.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_route_legend.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_tile_layer.dart';
import 'package:pinpoint/features/map/presentation/widgets/route_summary_sheet.dart';

/// Full-screen interactive OpenStreetMap with transport layers.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  var _showLayerPanel = false;
  var _mapReady = false;
  var _showRoutePanel = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(mapNotifierProvider.notifier);
      notifier.attachMapController(_mapController);
      notifier.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    if (!_mapReady && mounted) {
      setState(() => _mapReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final mapState = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zoom = mapState.mapZoom;
    final layers = mapState.layers;
    final mapRotation = MapCameraHelper.rotation(_mapController);

    ref.listen(mapNotifierProvider.select((s) => s.isGeneratingRoute), (previous, next) {
      if (next && mounted) {
        setState(() => _showRoutePanel = true);
      }
    });

    ref.listen(mapNotifierProvider.select((s) => s.plannedRoute), (previous, next) {
      if (next != null && previous == null && mounted) {
        setState(() => _showRoutePanel = true);
      }
    });

    ref.listen(mapNotifierProvider.select((s) => s.errorMessage), (previous, next) {
      if (next != null && next != previous && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(
                  AppConstants.butuanLat,
                  AppConstants.butuanLng,
                ),
                initialZoom: AppConstants.defaultMapZoom,
                minZoom: 11,
                maxZoom: 18,
                backgroundColor: const Color(0xFFCBD5E1),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onMapReady: _onMapReady,
                onPositionChanged: (camera, _) {
                  notifier.updateMapZoom(camera.zoom);
                },
              onLongPress: (_, point) async {
                final snapped = await notifier.prepareMapContext(point);
                if (!mounted) return;
                final items = notifier.buildNearbyItems(snapped.snapped).map(_toNearbyItem).toList();
                await MapNearbySheet.show(
                  context,
                  items: items,
                  onNavigateFrom: () => notifier.setOriginFromContext(snapped.snapped),
                  onNavigateTo: () => notifier.setDestinationFromContext(snapped.snapped),
                );
              },
              onTap: (_, point) async {
                if (mapState.pinMode != MapPinMode.none) {
                  await notifier.handleMapTap(point);
                  return;
                }
                if (mapState.selectedRoute != null) {
                  await notifier.handleMapTap(point);
                  return;
                }
                final ctx = await notifier.prepareMapContext(point);
                if (!mounted) return;
                await MapContextSheet.show(
                  context,
                  point: ctx.snapped,
                  address: ctx.address,
                  nearestStopName: ctx.nearestStop,
                  nearestStopDistanceM: ctx.nearestM,
                  onNavigateFrom: () => notifier.setOriginFromContext(ctx.snapped),
                  onNavigateTo: () => notifier.setDestinationFromContext(ctx.snapped),
                  onExploreNearby: () => notifier.exploreNearbyAt(ctx.snapped),
                );
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
              if (layers.showJeepneyLinesAtZoom(zoom) &&
                  mapState.filteredJeepneyRoutes.isNotEmpty)
                PolylineLayer(
                  polylines: mapState.filteredJeepneyRoutes.map((route) {
                    final isSelected = mapState.selectedRoute?.routeId == route.routeId;
                    final points =
                        mapState.roadRoutePolylines[route.routeId] ?? route.polyline;
                    return Polyline(
                      points: points,
                      color: colorFromHex(route.colorHex)
                          .withValues(alpha: isSelected ? 1 : 0.75),
                      strokeWidth: isSelected ? 6 : 4,
                    );
                  }).toList(),
                ),
              if (mapState.routeOptions.length > 1 && mapState.plannedRoute != null)
                PolylineLayer(
                  polylines: _buildPreviewPolylines(mapState),
                ),
              if (mapState.plannedRoute != null)
                PolylineLayer(
                  polylines: _buildColoredRoutePolylines(
                    mapState.plannedRoute!,
                    dimmed: mapState.previewOptionId != null &&
                        mapState.previewOptionId != mapState.plannedRoute!.optionId,
                  ),
                ),
              if (mapState.plannedRoute != null)
                MarkerLayer(
                  markers: _buildDirectionMarkers(mapState.plannedRoute!),
                ),
              MarkerLayer(
                markers: [
                  ..._buildFeaturedDestinationMarkers(mapState, notifier),
                  ..._buildStopMarkers(mapState, notifier, zoom),
                  ..._buildPoiMarkers(mapState),
                  ..._buildEmergencyMarkers(mapState),
                  if (mapState.currentLocation != null) ...[
                    if (mapState.currentLocation!.accuracyMeters != null)
                      _accuracyCircleMarker(mapState.currentLocation!),
                    _draggablePinMarker(
                      location: mapState.currentLocation!,
                      label: 'Start',
                      color: Theme.of(context).colorScheme.primary,
                      icon: Icons.trip_origin,
                      onDrag: notifier.updateOriginDrag,
                      onDragEnd: () => notifier.finishOriginDrag(),
                      controller: _mapController,
                    ),
                  ],
                  if (mapState.destination != null)
                    _draggablePinMarker(
                      location: mapState.destination!,
                      label: 'Destination',
                      color: AppColors.danger,
                      icon: Icons.place_rounded,
                      onDrag: notifier.updateDestinationDrag,
                      onDragEnd: () => notifier.finishDestinationDrag(),
                      controller: _mapController,
                    ),
                ],
              ),
            ],
            ),
          ),
          MapMinimalHeader(
            searchController: _searchController,
            onOpenTools: () => MapToolsSheet.show(context, _searchController),
          ),
          Positioned(
            right: AppSpacing.md,
            top: MediaQuery.paddingOf(context).top + 96,
            child: Column(
              children: [
                MapGlassButton(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onPressed: () {
                    final c = _mapController;
                    if (!MapCameraHelper.isReady(c)) return;
                    c.move(c.camera.center, c.camera.zoom + 1);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                MapGlassButton(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onPressed: () {
                    final c = _mapController;
                    if (!MapCameraHelper.isReady(c)) return;
                    c.move(c.camera.center, c.camera.zoom - 1);
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
                if (mapRotation.abs() > 0.5) ...[
                  const SizedBox(height: AppSpacing.sm),
                  MapGlassButton(
                    icon: Icons.explore_rounded,
                    tooltip: 'North up',
                    onPressed: notifier.resetMapRotation,
                  ),
                ],
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
                showStops: mapState.layers.showJeepneyStops,
                showStopLabels: mapState.layers.showStopLabels,
                showTransfers: mapState.layers.showTransferPoints,
                showTourist: mapState.layers.showTouristLayer,
                showEmergency: mapState.layers.showEmergency,
                showHighway: mapState.layers.showHighwayCorridors,
                onJeepneyChanged: (v) {
                  if (v) {
                    notifier.showAllRoutes();
                  } else {
                    notifier.clearRouteFilters();
                  }
                },
                onStopsChanged: (v) => notifier
                    .toggleLayer((l) => l.copyWith(showJeepneyStops: v)),
                onStopLabelsChanged: (v) => notifier
                    .toggleLayer((l) => l.copyWith(showStopLabels: v)),
                onTransfersChanged: (v) => notifier
                    .toggleLayer((l) => l.copyWith(showTransferPoints: v)),
                onTricycleChanged: (v) => notifier
                    .toggleLayer((l) => l.copyWith(showTricycleZones: v)),
                onTouristChanged: (v) => notifier
                    .toggleLayer((l) => l.copyWith(showTouristLayer: v)),
                onEmergencyChanged: (v) => notifier
                    .toggleLayer((l) => l.copyWith(showEmergency: v)),
                onHighwayChanged: (v) => notifier
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
          else if (_showRoutePanel || mapState.plannedRoute != null)
            Positioned.fill(
              child: RouteSummarySheet(
                route: mapState.plannedRoute,
                routeOptions: mapState.routeOptions,
                canGenerate: mapState.canGenerateRoute,
                isGenerating: mapState.isGeneratingRoute,
                originLabel: mapState.currentAddress ?? 'Start',
                destinationLabel:
                    mapState.destinationAddress ?? mapState.destination?.label,
                selectedVehicleMode: mapState.selectedVehicleMode,
                selectedRoutePreference: mapState.routePreference,
                highlightedStepIndex: mapState.highlightedStepIndex,
                onGenerate: () => notifier.generateRoute(),
                onSelectOption: (option) => notifier.selectRouteOption(option),
                onPreviewOption: (option) => notifier.previewRouteOption(option),
                onStepTap: (index) => notifier.focusRouteStep(index),
                onVehicleModeChanged: (mode) => notifier.setVehicleMode(mode),
                onPreferenceChanged: (pref) => notifier.setRoutePreference(pref),
                onClose: () => notifier.clearRoute(),
                onDismiss: () => setState(() => _showRoutePanel = false),
              ),
            ),
          if (!_showRoutePanel &&
              mapState.plannedRoute == null &&
              mapState.selectedRoute == null)
            Positioned(
              left: AppSpacing.lg,
              bottom: 88,
              child: FloatingActionButton.extended(
                heroTag: 'map-route-fab',
                elevation: 4,
                onPressed: mapState.isGeneratingRoute
                    ? null
                    : () async {
                        setState(() => _showRoutePanel = true);
                        if (mapState.canGenerateRoute) {
                          await notifier.generateRoute();
                        }
                      },
                icon: mapState.isGeneratingRoute
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.route_rounded, size: 20),
                label: Text(mapState.isGeneratingRoute ? 'Planning…' : 'Plan route'),
              ),
            ),
          if (mapState.plannedRoute != null)
            Positioned(
              left: AppSpacing.md,
              bottom: MediaQuery.sizeOf(context).height * 0.40,
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

  List<Marker> _buildStopMarkers(MapState mapState, MapNotifier notifier, double zoom) {
    if (!mapState.layers.showStopsAtZoom(zoom)) return [];
    final showLabels = mapState.layers.showLabelsAtZoom(zoom);
    return mapState.filteredJeepneyRoutes.expand((route) {
      return route.verifiedStops.map((stop) {
        final isTransfer = mapState.layers.showTransferPoints && notifier.isTransferStop(stop);
        final isTerminal = notifier.isTerminalStop(stop);
        final color = colorFromHex(route.colorHex);
        return Marker(
          point: stop.latLng,
          width: showLabels ? 120 : 36,
          height: showLabels ? 56 : 36,
          alignment: showLabels ? Alignment.bottomCenter : Alignment.center,
          child: GestureDetector(
            onTap: () => ref.read(mapNotifierProvider.notifier).selectJeepneyRoute(route),
            child: showLabels
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Text(
                          stop.name,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isTerminal
                            ? Icons.directions_bus_filled
                            : isTransfer
                                ? Icons.swap_horiz_rounded
                                : Icons.directions_bus_outlined,
                        color: color,
                        size: 28,
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: isTransfer ? Colors.white : color,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Icon(
                      isTerminal
                          ? Icons.directions_bus_filled
                          : isTransfer
                              ? Icons.swap_horiz_rounded
                              : Icons.circle,
                      size: isTransfer || isTerminal ? 16 : 8,
                      color: isTransfer ? color : Colors.white,
                    ),
                  ),
          ),
        );
      });
    }).toList();
  }

  MapNearbyItem _toNearbyItem(MapNearbyItemData data) {
    final icon = switch (data.kind) {
      'stop' => Icons.directions_bus_outlined,
      'tricycle' => Icons.moped_outlined,
      'hospital' => Icons.local_hospital_outlined,
      'police' => Icons.local_police_outlined,
      'tourist' || 'attraction' => Icons.attractions_outlined,
      'school' => Icons.school_outlined,
      'government' => Icons.account_balance_outlined,
      _ => Icons.place_outlined,
    };
    final color = switch (data.kind) {
      'stop' => AppColors.primary,
      'tricycle' => AppColors.warning,
      'hospital' => AppColors.danger,
      'police' => AppColors.primary,
      _ => AppColors.secondary,
    };
    return MapNearbyItem(
      icon: icon,
      color: color,
      label: data.label,
      subtitle: data.subtitle,
    );
  }

  List<Polyline> _buildPreviewPolylines(MapState mapState) {
    final selected = mapState.plannedRoute!;
    return mapState.routeOptions
        .where((o) => o.primaryMode != selected.primaryMode)
        .map((option) {
      final points = option.coloredSegments.isNotEmpty
          ? option.coloredSegments.expand((s) => s.polyline).toList()
          : option.fullPolyline;
      return Polyline(
        points: points,
        color: Colors.grey.withValues(alpha: 0.45),
        strokeWidth: 3,
        pattern: StrokePattern.dashed(segments: [8, 12]),
      );
    }).toList();
  }

  List<Marker> _buildDirectionMarkers(PlannedRoute route) {
    return route.coloredSegments.expand((segment) {
      if (segment.type == RouteStepType.walk) return const <Marker>[];
      return MapPolylineUtils.directionMarkers(
        segment.polyline,
        color: colorFromHex(segment.colorHex),
      );
    }).toList();
  }

  List<Marker> _buildFeaturedDestinationMarkers(
    MapState mapState,
    MapNotifier notifier,
  ) {
    return mapState.featuredDestinations.map((dest) {
      final color = PlaceUtils.colorForCategory(dest.place.category);
      final isSelected = mapState.destinationAddress != null &&
          (mapState.destinationAddress == dest.place.name ||
              mapState.destinationAddress!.contains(dest.shortLabel));
      return Marker(
        point: dest.place.latLng,
        width: 110,
        height: 58,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () => FeaturedDestinationSheet.show(
            context,
            destination: dest,
            onNavigateTo: () => notifier.selectFeaturedDestination(dest),
            onNavigateFrom: () => notifier.selectFeaturedAsOrigin(dest),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: isSelected ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  dest.shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
              Icon(
                PlaceUtils.iconForCategory(dest.place.category),
                color: color,
                size: 26,
              ),
            ],
          ),
        ),
      );
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

  List<Polyline> _buildColoredRoutePolylines(PlannedRoute route, {bool dimmed = false}) {
    final alpha = dimmed ? 0.35 : 1.0;
    if (route.coloredSegments.isNotEmpty) {
      return route.coloredSegments.map((segment) {
        final isWalk = segment.type == RouteStepType.walk;
        return Polyline(
          points: segment.polyline,
          color: colorFromHex(segment.colorHex).withValues(alpha: alpha),
          strokeWidth: isWalk ? 4 : 7,
          borderColor: Colors.white.withValues(alpha: alpha),
          borderStrokeWidth: isWalk ? 1 : 2,
        );
      }).toList();
    }
    return [
      Polyline(
        points: route.fullPolyline,
        color: AppColors.accent.withValues(alpha: alpha),
        strokeWidth: 5,
        borderColor: Colors.white.withValues(alpha: alpha),
        borderStrokeWidth: 2,
      ),
    ];
  }

  Marker _accuracyCircleMarker(MapLocation location) {
    final radius = location.accuracyMeters ?? 30;
    final diameter = (radius * 2).clamp(40, 200).toDouble();
    return Marker(
      point: location.latLng,
      width: diameter,
      height: diameter,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
      ),
    );
  }

  Marker _draggablePinMarker({
    required MapLocation location,
    required String label,
    required Color color,
    required IconData icon,
    required ValueChanged<LatLng> onDrag,
    required VoidCallback onDragEnd,
    required MapController? controller,
  }) {
    return Marker(
      point: location.latLng,
      width: 120,
      height: 72,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          if (!MapCameraHelper.isReady(controller)) return;
          final camera = controller!.camera;
          final screen = camera.latLngToScreenPoint(location.latLng);
          final next = camera.pointToLatLng(
            math.Point(screen.x + details.delta.dx, screen.y + details.delta.dy),
          );
          onDrag(next);
        },
        onPanEnd: (_) => onDragEnd(),
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
      ),
    );
  }
}
