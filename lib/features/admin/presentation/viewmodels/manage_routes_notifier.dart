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
      // Tap path is faster and more reliable than freehand brush.
      drawTool: RouteDrawTool.pin,
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
    final route = state.selectedRoute;
    if (route == null) return;
    // Keep the saved corridor intact; termini are enough to extend or reshape.
    final termini = route.polyline.length >= 2
        ? [route.polyline.first, route.polyline.last]
        : _sampleWaypoints(route.polyline);
    state = state.copyWith(
      mode: ManageRoutesMode.editing,
      drawTool: RouteDrawTool.pin,
      waypoints: termini,
      corridor: route.polyline,
      freehandTrace: const [],
      replacedPathWhileEditing: false,
      clearError: true,
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
    // Brush mode: a tap is just a quick pin (no awkward micro-stroke match).
    await addWaypoint(point);
  }

  void beginBrushStroke(LatLng point) {
    if (!state.canDrawPath || state.drawTool != RouteDrawTool.brush) return;
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
        _distance.as(LengthUnit.Meter, trace.last, point) < 8) {
      return;
    }
    state = state.copyWith(freehandTrace: [...trace, point]);
  }

  Future<void> endBrushStroke() async {
    if (!state.isBrushStrokeActive) return;
    final trace = state.freehandTrace;
    state = state.copyWith(isBrushStrokeActive: false, isSnapping: true);

    // Accidental tap / tiny stroke → treat as a single pin instead of failing.
    if (trace.length < 3) {
      state = state.copyWith(freehandTrace: const [], isSnapping: false);
      if (trace.isNotEmpty) await addWaypoint(trace.last);
      return;
    }

    try {
      List<LatLng> matched = await _routing.matchTraceToRoads(trace);
      // Fallback: if OSRM Match fails, route start→end of the stroke.
      if (matched.length < 2) {
        matched = await _routing.routeThroughWaypoints([trace.first, trace.last]);
      }
      if (matched.length < 2) {
        final drive = await _routing.getDrivingRoute(trace.first, trace.last);
        matched = drive.polyline.length >= 2
            ? drive.polyline
            : [trace.first, trace.last];
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
        if (gap < 60) {
          mergedCorridor = [...state.corridor, ...matched.skip(1)];
        } else {
          final bridge = await _routing.getDrivingRoute(
            state.corridor.last,
            matched.first,
          );
          final bridgePts = bridge.polyline.length >= 2
              ? bridge.polyline
              : [state.corridor.last, matched.first];
          mergedCorridor = [
            ...state.corridor,
            ...bridgePts.skip(1),
            ...matched.skip(1),
          ];
        }
      }

      // Keep prior control points; append stroke end so Undo stays useful.
      final waypoints = <LatLng>[...state.waypoints];
      if (waypoints.isEmpty) waypoints.add(matched.first);
      if (waypoints.isEmpty ||
          _distance.as(LengthUnit.Meter, waypoints.last, matched.last) >= 25) {
        waypoints.add(matched.last);
      }

      state = state.copyWith(
        corridor: mergedCorridor,
        waypoints: waypoints,
        freehandTrace: const [],
        isSnapping: false,
        clearError: true,
      );
    } catch (error) {
      // Last resort: pin the end of the stroke so the admin never loses progress.
      state = state.copyWith(freehandTrace: const [], isSnapping: false);
      try {
        await addWaypoint(trace.last);
      } catch (_) {
        state = state.copyWith(
          errorMessage: 'Could not snap that stroke. Try Tap path instead.',
        );
      }
    }
  }

  Future<void> addWaypoint(LatLng point) async {
    state = state.copyWith(isSnapping: true, clearError: true);
    try {
      final snapped = await _routing.snapToNearestRoad(point);
      // Ignore accidental double-taps on the same spot.
      if (state.waypoints.isNotEmpty &&
          _distance.as(LengthUnit.Meter, state.waypoints.last, snapped) < 25) {
        state = state.copyWith(isSnapping: false);
        return;
      }

      // Extend an existing corridor from its tip — preserves what you already drew.
      if (state.corridor.length >= 2) {
        final segment = await _routing.routeThroughWaypoints([
          state.corridor.last,
          snapped,
        ]);
        final extension = segment.length >= 2
            ? segment
            : [state.corridor.last, snapped];
        state = state.copyWith(
          waypoints: [...state.waypoints, snapped],
          corridor: [...state.corridor, ...extension.skip(1)],
          isSnapping: false,
        );
        return;
      }

      final waypoints = [...state.waypoints, snapped];
      if (waypoints.length == 1) {
        state = state.copyWith(
          waypoints: waypoints,
          corridor: [snapped],
          isSnapping: false,
        );
        return;
      }
      final corridor = await _routing.routeThroughWaypoints(waypoints);
      state = state.copyWith(
        waypoints: waypoints,
        corridor: corridor.length >= 2 ? corridor : waypoints,
        isSnapping: false,
      );
    } catch (error) {
      state = state.copyWith(isSnapping: false, errorMessage: error.toString());
    }
  }

  Future<void> undoLastWaypoint() async {
    if (state.waypoints.isEmpty && state.corridor.isEmpty) return;

    // Editing an existing route: with only the original termini, Undo restores
    // the saved corridor instead of wiping it to a single pin.
    if (state.mode == ManageRoutesMode.editing &&
        !state.replacedPathWhileEditing &&
        state.selectedRoute != null &&
        state.waypoints.length <= 2) {
      final route = state.selectedRoute!;
      state = state.copyWith(
        waypoints: route.polyline.length >= 2
            ? [route.polyline.first, route.polyline.last]
            : const [],
        corridor: List.of(route.polyline),
        freehandTrace: const [],
        isBrushStrokeActive: false,
      );
      return;
    }

    if (state.waypoints.length <= 1) {
      clearPath();
      return;
    }

    final waypoints = [...state.waypoints]..removeLast();
    final tip = waypoints.last;

    // Prefer trimming the drawn corridor so Undo keeps earlier road shape.
    var cutAt = 0;
    var best = double.infinity;
    for (var i = 0; i < state.corridor.length; i++) {
      final d = _distance.as(LengthUnit.Meter, state.corridor[i], tip);
      if (d < best) {
        best = d;
        cutAt = i;
      }
    }
    if (best < 90 && cutAt >= 0) {
      state = state.copyWith(
        waypoints: waypoints,
        corridor: state.corridor.sublist(0, cutAt + 1),
      );
      return;
    }

    state = state.copyWith(isSnapping: true);
    if (waypoints.length == 1) {
      state = state.copyWith(
        waypoints: waypoints,
        corridor: [waypoints.first],
        isSnapping: false,
      );
      return;
    }
    final corridor = await _routing.routeThroughWaypoints(waypoints);
    state = state.copyWith(
      waypoints: waypoints,
      corridor: corridor.length >= 2 ? corridor : waypoints,
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
      replacedPathWhileEditing: state.mode == ManageRoutesMode.editing,
    );
  }

  void finishDrawing() {
    if (state.corridor.length < 2) {
      state = state.copyWith(
        errorMessage: 'Tap Start and End on the map first (or use Brush along the streets).',
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
