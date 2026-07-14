import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_routes_state.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

class ManageRoutesNotifier extends Notifier<ManageRoutesState> {
  static const _distance = Distance();

  RoutingService get _routing => ref.read(routingServiceProvider);

  @override
  ManageRoutesState build() => const ManageRoutesState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final routes = await ref.read(adminRepositoryProvider).getAdminRoutes();
      state = state.copyWith(isLoading: false, routes: routes);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setDrawTool(RouteDrawTool tool) {
    state = state.copyWith(drawTool: tool, freehandTrace: const []);
  }

  void startCreate() {
    final preset = VehicleRoutePreset.forType('jeepney');
    state = state.copyWith(
      mode: ManageRoutesMode.drawing,
      drawTool: RouteDrawTool.brush,
      clearSelection: true,
      waypoints: const [],
      corridor: const [],
      freehandTrace: const [],
      draftStops: const [],
      routeCode: _suggestCode(preset),
      routeName: '',
      vehicleType: preset.value,
      colorHex: preset.colorHex,
      baseFare: preset.suggestedBaseFare,
      additionalFare: preset.suggestedAdditionalFare,
      description: '',
      activeStatus: true,
      isBrushStrokeActive: false,
      clearError: true,
      clearSuccess: true,
    );
  }

  void cancelEditing() {
    state = state.copyWith(
      mode: ManageRoutesMode.browse,
      waypoints: const [],
      corridor: const [],
      freehandTrace: const [],
      draftStops: const [],
      clearSelection: true,
      isBrushStrokeActive: false,
      clearError: true,
    );
  }

  void selectRoute(JeepneyRoute route) {
    state = state.copyWith(
      selectedRouteId: route.routeId,
      mode: ManageRoutesMode.browse,
      waypoints: _sampleWaypoints(route.polyline),
      corridor: route.polyline,
      freehandTrace: const [],
      draftStops: route.stops
          .map(
            (s) => DraftStop(
              name: s.name,
              point: s.latLng,
              order: s.order,
              description: s.description,
            ),
          )
          .toList(),
      routeCode: route.routeCode,
      routeName: route.routeName,
      vehicleType: route.vehicleType,
      colorHex: route.colorHex,
      baseFare: route.baseFare,
      additionalFare: route.additionalFare,
      description: route.description ?? '',
      activeStatus: route.activeStatus,
      clearError: true,
      clearSuccess: true,
    );
  }

  void beginEditSelected() {
    if (state.selectedRoute == null) return;
    state = state.copyWith(
      mode: ManageRoutesMode.editing,
      drawTool: RouteDrawTool.pin,
      freehandTrace: const [],
    );
  }

  void beginEditDetails() {
    if (state.selectedRoute == null) return;
    state = state.copyWith(mode: ManageRoutesMode.metadata);
  }

  Future<void> onMapTap(LatLng point) async {
    if (state.mode == ManageRoutesMode.placingStops) {
      await _addStopAt(point);
      return;
    }
    if (!state.canDrawPath) return;
    if (state.drawTool == RouteDrawTool.brush) {
      // Brush uses press/drag; a single tap starts a short stroke and matches it.
      beginBrushStroke(point);
      await endBrushStroke();
      return;
    }
    await addWaypoint(point);
  }

  void beginBrushStroke(LatLng point) {
    if (!state.canDrawPath) return;
    state = state.copyWith(
      isBrushStrokeActive: true,
      freehandTrace: [point],
      clearError: true,
    );
  }

  void extendBrushStroke(LatLng point) {
    if (!state.isBrushStrokeActive || !state.canDrawPath) return;
    final trace = state.freehandTrace;
    if (trace.isNotEmpty &&
        _distance.as(LengthUnit.Meter, trace.last, point) < 12) {
      return;
    }
    state = state.copyWith(freehandTrace: [...trace, point]);
  }

  Future<void> endBrushStroke() async {
    if (!state.isBrushStrokeActive) return;
    final trace = state.freehandTrace;
    state = state.copyWith(isBrushStrokeActive: false, isSnapping: true);
    if (trace.length < 2) {
      state = state.copyWith(
        freehandTrace: const [],
        isSnapping: false,
        errorMessage: 'Drag along the road a bit farther to draw a path.',
      );
      return;
    }

    try {
      final matched = await _routing.matchTraceToRoads(trace);
      if (matched.length < 2) {
        state = state.copyWith(
          freehandTrace: const [],
          isSnapping: false,
          errorMessage: 'Could not snap that stroke to roads. Try again.',
        );
        return;
      }

      List<LatLng> mergedCorridor;
      if (state.corridor.isEmpty) {
        mergedCorridor = matched;
      } else {
        final gap = _distance.as(
          LengthUnit.Meter,
          state.corridor.last,
          matched.first,
        );
        if (gap < 40) {
          mergedCorridor = [...state.corridor, ...matched.skip(1)];
        } else {
          final bridge = await _routing.getDrivingRoute(
            state.corridor.last,
            matched.first,
          );
          final bridgePts = bridge.polyline.isNotEmpty
              ? bridge.polyline
              : [state.corridor.last, matched.first];
          mergedCorridor = [
            ...state.corridor,
            ...bridgePts.skip(1),
            ...matched.skip(1),
          ];
        }
      }

      final waypoints = [
        if (state.waypoints.isEmpty) matched.first else state.waypoints.first,
        matched.last,
      ];

      state = state.copyWith(
        corridor: mergedCorridor,
        waypoints: waypoints,
        freehandTrace: const [],
        isSnapping: false,
      );
    } catch (error) {
      state = state.copyWith(
        freehandTrace: const [],
        isSnapping: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> addWaypoint(LatLng point) async {
    state = state.copyWith(isSnapping: true, clearError: true);
    try {
      final snapped = await _routing.snapToNearestRoad(point);
      final waypoints = [...state.waypoints, snapped];
      final corridor = await _routing.routeThroughWaypoints(waypoints);
      state = state.copyWith(
        waypoints: waypoints,
        corridor: corridor,
        isSnapping: false,
      );
    } catch (error) {
      state = state.copyWith(isSnapping: false, errorMessage: error.toString());
    }
  }

  Future<void> undoLastWaypoint() async {
    if (state.waypoints.isEmpty && state.corridor.isEmpty) return;
    if (state.waypoints.length <= 1) {
      clearPath();
      return;
    }
    final waypoints = [...state.waypoints]..removeLast();
    state = state.copyWith(isSnapping: true);
    final corridor = await _routing.routeThroughWaypoints(waypoints);
    state = state.copyWith(
      waypoints: waypoints,
      corridor: corridor,
      isSnapping: false,
    );
  }

  void clearPath() {
    state = state.copyWith(
      waypoints: const [],
      corridor: const [],
      freehandTrace: const [],
      draftStops: const [],
      isBrushStrokeActive: false,
    );
  }

  void finishDrawing() {
    if (state.corridor.length < 2) {
      state = state.copyWith(
        errorMessage: 'Draw the road path first (brush along streets or pin points).',
      );
      return;
    }
    // Auto-suggest stops when none exist yet so the flow feels complete.
    final stops = state.draftStops.isEmpty
        ? _suggestStopsAlongCorridor(state.corridor)
        : state.draftStops;
    state = state.copyWith(
      mode: ManageRoutesMode.metadata,
      draftStops: stops,
      clearError: true,
    );
  }

  void applyVehiclePreset(String vehicleType) {
    final preset = VehicleRoutePreset.forType(vehicleType);
    final code = state.selectedRouteId == null
        ? _suggestCode(preset)
        : state.routeCode;
    state = state.copyWith(
      vehicleType: preset.value,
      colorHex: preset.colorHex,
      baseFare: preset.suggestedBaseFare,
      additionalFare: preset.suggestedAdditionalFare,
      routeCode: code,
    );
  }

  void updateMetadata({
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
  }) {
    if (vehicleType != null && vehicleType != state.vehicleType) {
      applyVehiclePreset(vehicleType);
    }
    state = state.copyWith(
      routeCode: routeCode,
      routeName: routeName,
      colorHex: colorHex,
      baseFare: baseFare,
      clearBaseFare: clearBaseFare,
      additionalFare: additionalFare,
      clearAdditionalFare: clearAdditionalFare,
      description: description,
      activeStatus: activeStatus,
    );
  }

  void continueToStops() {
    if (state.routeName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Route name is required.');
      return;
    }
    if (state.routeCode.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Route code is required (e.g. R8).');
      return;
    }
    final stops = state.draftStops.isEmpty
        ? _suggestStopsAlongCorridor(state.corridor)
        : state.draftStops;
    state = state.copyWith(
      mode: ManageRoutesMode.placingStops,
      draftStops: stops,
      clearError: true,
    );
  }

  void regenerateSuggestedStops() {
    if (state.corridor.length < 2) return;
    state = state.copyWith(draftStops: _suggestStopsAlongCorridor(state.corridor));
  }

  Future<void> _addStopAt(LatLng point) async {
    state = state.copyWith(isSnapping: true);
    final onRoad = await _routing.snapToNearestRoad(point);
    final onCorridor = state.corridor.length >= 2
        ? _routing.projectOntoPolyline(onRoad, state.corridor)
        : onRoad;
    final order = state.draftStops.length + 1;
    final stop = DraftStop(
      name: order == 1
          ? 'Start'
          : 'Stop $order',
      point: onCorridor,
      order: order,
    );
    state = state.copyWith(
      draftStops: [...state.draftStops, stop],
      isSnapping: false,
    );
  }

  void updateDraftStop(int index, {String? name, String? description}) {
    if (index < 0 || index >= state.draftStops.length) return;
    final updated = [...state.draftStops];
    updated[index] = updated[index].copyWith(name: name, description: description);
    state = state.copyWith(draftStops: updated);
  }

  void removeDraftStop(int index) {
    if (index < 0 || index >= state.draftStops.length) return;
    final updated = [...state.draftStops]..removeAt(index);
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(order: i + 1);
    }
    state = state.copyWith(draftStops: updated);
  }

  Future<bool> save() async {
    if (state.corridor.length < 2) {
      state = state.copyWith(errorMessage: 'Route path is incomplete.');
      return false;
    }
    if (state.routeName.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Route name is required.');
      return false;
    }
    if (state.routeCode.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Route code is required.');
      return false;
    }

    // Ensure termini exist as stops for passenger boarding.
    var stops = state.draftStops;
    if (stops.length < 2 && state.corridor.length >= 2) {
      stops = _suggestStopsAlongCorridor(state.corridor);
    }

    state = state.copyWith(
      draftStops: stops,
      isSaving: true,
      clearError: true,
      clearSuccess: true,
    );
    final payload = _buildPayload();
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (state.selectedRouteId != null) {
        await repo.updateRoute(state.selectedRouteId!, payload);
      } else {
        await repo.createRoute(payload);
      }
      await load();
      state = state.copyWith(
        isSaving: false,
        mode: ManageRoutesMode.browse,
        successMessage:
            '${VehicleRoutePreset.forType(state.vehicleType).label} route saved — now usable by passengers',
        waypoints: const [],
        corridor: const [],
        freehandTrace: const [],
        draftStops: const [],
        clearSelection: true,
      );
      try {
        await ref.read(transportRepositoryProvider).refreshFromRemote();
      } catch (_) {}
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<bool> deleteSelected() async {
    final id = state.selectedRouteId;
    if (id == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(adminRepositoryProvider).deleteRoute(id);
      await load();
      state = state.copyWith(
        isSaving: false,
        mode: ManageRoutesMode.browse,
        clearSelection: true,
        waypoints: const [],
        corridor: const [],
        freehandTrace: const [],
        draftStops: const [],
        successMessage: 'Route deleted',
      );
      try {
        await ref.read(transportRepositoryProvider).refreshFromRemote();
      } catch (_) {}
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'route_code': state.routeCode.trim().toUpperCase(),
      'route_name': state.routeName.trim(),
      'color': state.colorHex,
      'vehicle_type': state.vehicleType,
      'description': state.description.trim().isEmpty ? null : state.description.trim(),
      'active_status': state.activeStatus,
      'base_fare': state.baseFare,
      'additional_fare': state.additionalFare,
      'corridor_geojson': {
        'type': 'LineString',
        'coordinates': state.corridor.map((p) => [p.longitude, p.latitude]).toList(),
      },
      'stops': state.draftStops.map((s) => s.toApiJson()).toList(),
    };
  }

  String _suggestCode(VehicleRoutePreset preset) {
    final existing = state.routes
        .map((r) => r.routeCode.toUpperCase())
        .where((c) => c.startsWith(preset.codePrefix))
        .toSet();
    for (var n = 1; n < 100; n++) {
      final candidate = '${preset.codePrefix}$n';
      if (!existing.contains(candidate)) return candidate;
    }
    return '${preset.codePrefix}${state.routes.length + 1}';
  }

  List<DraftStop> _suggestStopsAlongCorridor(List<LatLng> corridor) {
    if (corridor.length < 2) return const [];

    var total = 0.0;
    for (var i = 0; i < corridor.length - 1; i++) {
      total += _distance.as(LengthUnit.Meter, corridor[i], corridor[i + 1]);
    }
    if (total < 50) {
      return [
        DraftStop(name: 'Start', point: corridor.first, order: 1),
        DraftStop(name: 'End', point: corridor.last, order: 2),
      ];
    }

    // Aim for a stop roughly every 600–900 m, with termini always included.
    final targetSpacing = total < 1500 ? total / 2 : 700.0;
    final points = <LatLng>[corridor.first];
    var traveled = 0.0;
    var nextAt = targetSpacing;

    for (var i = 0; i < corridor.length - 1; i++) {
      final a = corridor[i];
      final b = corridor[i + 1];
      final seg = _distance.as(LengthUnit.Meter, a, b);
      if (seg <= 0) continue;
      var segStart = traveled;
      while (nextAt > segStart && nextAt <= traveled + seg) {
        final t = (nextAt - traveled) / seg;
        points.add(
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
        );
        nextAt += targetSpacing;
      }
      traveled += seg;
    }

    if (points.last != corridor.last) points.add(corridor.last);

    return [
      for (var i = 0; i < points.length; i++)
        DraftStop(
          name: i == 0
              ? 'Start'
              : (i == points.length - 1 ? 'End' : 'Stop ${i + 1}'),
          point: points[i],
          order: i + 1,
        ),
    ];
  }

  List<LatLng> _sampleWaypoints(List<LatLng> polyline) {
    if (polyline.length <= 12) return List.of(polyline);
    final step = (polyline.length / 10).ceil();
    final points = <LatLng>[];
    for (var i = 0; i < polyline.length; i += step) {
      points.add(polyline[i]);
    }
    if (points.last != polyline.last) points.add(polyline.last);
    return points;
  }
}

final manageRoutesNotifierProvider =
    NotifierProvider<ManageRoutesNotifier, ManageRoutesState>(ManageRoutesNotifier.new);
