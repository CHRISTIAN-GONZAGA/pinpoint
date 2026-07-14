import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_routes_notifier.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_routes_state.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_tile_layer.dart';

/// Full-screen admin map: draw along roads, then assign a vehicle to that corridor.
class ManageRoutesScreen extends ConsumerStatefulWidget {
  const ManageRoutesScreen({super.key});

  @override
  ConsumerState<ManageRoutesScreen> createState() => _ManageRoutesScreenState();
}

class _ManageRoutesScreenState extends ConsumerState<ManageRoutesScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _baseFareController = TextEditingController();
  final _additionalFareController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(manageRoutesNotifierProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _baseFareController.dispose();
    _additionalFareController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _syncFormFromState(ManageRoutesState state) {
    if (_nameController.text != state.routeName) {
      _nameController.text = state.routeName;
    }
    if (_codeController.text != state.routeCode) {
      _codeController.text = state.routeCode;
    }
    if (_descriptionController.text != state.description) {
      _descriptionController.text = state.description;
    }
    final base = state.baseFare?.toString() ?? '';
    if (_baseFareController.text != base) _baseFareController.text = base;
    final add = state.additionalFare?.toString() ?? '';
    if (_additionalFareController.text != add) _additionalFareController.text = add;
  }

  LatLng? _toLatLng(Offset local) {
    try {
      final camera = _mapController.camera;
      return camera.pointToLatLng(math.Point(local.dx, local.dy));
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete route?'),
        content: const Text('This permanently removes the route and its stops.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ref.read(manageRoutesNotifierProvider.notifier).deleteSelected();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Route deleted' : 'Failed to delete route')),
    );
  }

  void _pushMetadataFromFields(ManageRoutesNotifier notifier) {
    notifier.updateMetadata(
      routeCode: _codeController.text,
      routeName: _nameController.text,
      description: _descriptionController.text,
      baseFare: double.tryParse(_baseFareController.text),
      additionalFare: double.tryParse(_additionalFareController.text),
      clearBaseFare: _baseFareController.text.trim().isEmpty,
      clearAdditionalFare: _additionalFareController.text.trim().isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manageRoutesNotifierProvider);
    final notifier = ref.read(manageRoutesNotifierProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brushDrawing = state.canDrawPath && state.drawTool == RouteDrawTool.brush;

    ref.listen(manageRoutesNotifierProvider, (prev, next) {
      _syncFormFromState(next);
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Routes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (state.mode != ManageRoutesMode.browse) {
              notifier.cancelEditing();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (state.mode == ManageRoutesMode.browse)
            TextButton.icon(
              onPressed: notifier.startCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
        ],
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: brushDrawing
                    ? (event) {
                        final latLng = _toLatLng(event.localPosition);
                        if (latLng != null) notifier.beginBrushStroke(latLng);
                      }
                    : null,
                onPointerMove: brushDrawing
                    ? (event) {
                        final latLng = _toLatLng(event.localPosition);
                        if (latLng != null) notifier.extendBrushStroke(latLng);
                      }
                    : null,
                onPointerUp: brushDrawing
                    ? (_) => notifier.endBrushStroke()
                    : null,
                onPointerCancel: brushDrawing
                    ? (_) => notifier.endBrushStroke()
                    : null,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        const LatLng(AppConstants.butuanLat, AppConstants.butuanLng),
                    initialZoom: AppConstants.defaultMapZoom,
                    interactionOptions: InteractionOptions(
                      flags: brushDrawing
                          ? (InteractiveFlag.all &
                              ~InteractiveFlag.drag &
                              ~InteractiveFlag.flingAnimation &
                              ~InteractiveFlag.rotate)
                          : InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: state.mode == ManageRoutesMode.placingStops ||
                            (state.canDrawPath && state.drawTool == RouteDrawTool.pin)
                        ? (_, point) => notifier.onMapTap(point)
                        : null,
                  ),
                  children: [
                    PinpointTileLayer(isDark: isDark),
                    PolylineLayer(
                      polylines: [
                        for (final route in state.routes)
                          if (route.polyline.length >= 2)
                            Polyline(
                              points: route.polyline,
                              strokeWidth:
                                  route.routeId == state.selectedRouteId ? 7 : 4,
                              color: colorFromHex(route.colorHex).withValues(
                                alpha: state.selectedRouteId == null ||
                                        route.routeId == state.selectedRouteId
                                    ? 0.85
                                    : 0.28,
                              ),
                            ),
                        if (state.corridor.length >= 2)
                          Polyline(
                            points: state.corridor,
                            strokeWidth: 7,
                            color: colorFromHex(state.colorHex),
                            borderStrokeWidth: 2,
                            borderColor: Colors.white.withValues(alpha: 0.85),
                          ),
                        if (state.freehandTrace.length >= 2)
                          Polyline(
                            points: state.freehandTrace,
                            strokeWidth: 4,
                            color: colorFromHex(state.colorHex).withValues(alpha: 0.45),
                            pattern: StrokePattern.dashed(segments: const [8, 8]),
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (var i = 0; i < state.waypoints.length; i++)
                          Marker(
                            point: state.waypoints[i],
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? Colors.green
                                    : (i == state.waypoints.length - 1
                                        ? Colors.red
                                        : Colors.white),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorFromHex(state.colorHex),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        for (final stop in state.draftStops)
                          Marker(
                            point: stop.point,
                            width: 34,
                            height: 34,
                            child: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                '${stop.order}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (state.selectedRoute != null &&
                            state.mode == ManageRoutesMode.browse)
                          for (final stop in state.selectedRoute!.stops)
                            Marker(
                              point: stop.latLng,
                              width: 30,
                              height: 30,
                              child: CircleAvatar(
                                radius: 13,
                                backgroundColor:
                                    colorFromHex(state.selectedRoute!.colorHex),
                                child: Text(
                                  '${stop.order}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            right: 56,
            child: _WorkflowBanner(state: state),
          ),
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.add,
                  onTap: () {
                    final camera = _mapController.camera;
                    _mapController.move(camera.center, camera.zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.remove,
                  onTap: () {
                    final camera = _mapController.camera;
                    _mapController.move(camera.center, camera.zoom - 1);
                  },
                ),
              ],
            ),
          ),
          if (state.isLoading || state.isSnapping || state.isSaving)
            const Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPanel(
              state: state,
              searchController: _searchController,
              nameController: _nameController,
              codeController: _codeController,
              descriptionController: _descriptionController,
              baseFareController: _baseFareController,
              additionalFareController: _additionalFareController,
              onSearch: notifier.setSearchQuery,
              onSelect: (route) {
                notifier.selectRoute(route);
                if (route.polyline.isNotEmpty) {
                  _mapController.move(route.polyline[route.polyline.length ~/ 2], 14);
                }
              },
              onCreate: notifier.startCreate,
              onDrawTool: notifier.setDrawTool,
              onUndo: notifier.undoLastWaypoint,
              onClear: notifier.clearPath,
              onFinishDrawing: notifier.finishDrawing,
              onContinueStops: () {
                _pushMetadataFromFields(notifier);
                notifier.continueToStops();
              },
              onSave: () async {
                _pushMetadataFromFields(notifier);
                await notifier.save();
              },
              onCancel: notifier.cancelEditing,
              onEdit: notifier.beginEditSelected,
              onEditDetails: notifier.beginEditDetails,
              onDelete: _confirmDelete,
              onVehicleType: notifier.applyVehiclePreset,
              onColor: (c) => notifier.updateMetadata(colorHex: c),
              onActive: (v) => notifier.updateMetadata(activeStatus: v),
              onStopName: (i, name) => notifier.updateDraftStop(i, name: name),
              onRemoveStop: notifier.removeDraftStop,
              onRegenerateStops: notifier.regenerateSuggestedStops,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowBanner extends StatelessWidget {
  const _WorkflowBanner({required this.state});

  final ManageRoutesState state;

  @override
  Widget build(BuildContext context) {
    if (state.mode == ManageRoutesMode.browse) {
      return Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            'Tap a route to inspect it, or Create to draw a new road corridor.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      );
    }

    final step = state.workflowStep;
    final labels = const ['Draw path', 'Assign vehicle', 'Stops'];
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: step > i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
              CircleAvatar(
                radius: 11,
                backgroundColor: step >= i + 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: step == i + 1 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 40, height: 40, child: Icon(icon)),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.searchController,
    required this.nameController,
    required this.codeController,
    required this.descriptionController,
    required this.baseFareController,
    required this.additionalFareController,
    required this.onSearch,
    required this.onSelect,
    required this.onCreate,
    required this.onDrawTool,
    required this.onUndo,
    required this.onClear,
    required this.onFinishDrawing,
    required this.onContinueStops,
    required this.onSave,
    required this.onCancel,
    required this.onEdit,
    required this.onEditDetails,
    required this.onDelete,
    required this.onVehicleType,
    required this.onColor,
    required this.onActive,
    required this.onStopName,
    required this.onRemoveStop,
    required this.onRegenerateStops,
  });

  final ManageRoutesState state;
  final TextEditingController searchController;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController descriptionController;
  final TextEditingController baseFareController;
  final TextEditingController additionalFareController;
  final ValueChanged<String> onSearch;
  final ValueChanged<JeepneyRoute> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<RouteDrawTool> onDrawTool;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onFinishDrawing;
  final VoidCallback onContinueStops;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;
  final VoidCallback onEdit;
  final VoidCallback onEditDetails;
  final VoidCallback onDelete;
  final ValueChanged<String> onVehicleType;
  final ValueChanged<String> onColor;
  final ValueChanged<bool> onActive;
  final void Function(int index, String name) onStopName;
  final ValueChanged<int> onRemoveStop;
  final VoidCallback onRegenerateStops;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
          child: switch (state.mode) {
            ManageRoutesMode.browse => _BrowsePanel(
                state: state,
                searchController: searchController,
                onSearch: onSearch,
                onSelect: onSelect,
                onCreate: onCreate,
                onEdit: onEdit,
                onEditDetails: onEditDetails,
                onDelete: onDelete,
              ),
            ManageRoutesMode.drawing || ManageRoutesMode.editing => _DrawPanel(
                state: state,
                onDrawTool: onDrawTool,
                onUndo: onUndo,
                onClear: onClear,
                onFinishDrawing: onFinishDrawing,
                onCancel: onCancel,
                onSave: state.mode == ManageRoutesMode.editing ? onSave : null,
              ),
            ManageRoutesMode.metadata => _MetadataPanel(
                state: state,
                nameController: nameController,
                codeController: codeController,
                descriptionController: descriptionController,
                baseFareController: baseFareController,
                additionalFareController: additionalFareController,
                onVehicleType: onVehicleType,
                onColor: onColor,
                onActive: onActive,
                onContinueStops: onContinueStops,
                onCancel: onCancel,
              ),
            ManageRoutesMode.placingStops => _StopsPanel(
                state: state,
                onStopName: onStopName,
                onRemoveStop: onRemoveStop,
                onRegenerateStops: onRegenerateStops,
                onSave: onSave,
                onCancel: onCancel,
              ),
          },
        ),
      ),
    );
  }
}

class _BrowsePanel extends StatelessWidget {
  const _BrowsePanel({
    required this.state,
    required this.searchController,
    required this.onSearch,
    required this.onSelect,
    required this.onCreate,
    required this.onEdit,
    required this.onEditDetails,
    required this.onDelete,
  });

  final ManageRoutesState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<JeepneyRoute> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onEditDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedRoute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search routes…',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onSearch,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (selected != null) ...[
          Text(
            '${selected.routeCode} · ${selected.routeName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${VehicleTypeMapping.displayName(selected.vehicleType)} · '
            '${selected.activeStatus ? "Active" : "Inactive"} · '
            '${selected.stops.length} stops',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: onEdit, child: const Text('Edit path')),
              OutlinedButton(onPressed: onEditDetails, child: const Text('Details')),
              OutlinedButton(onPressed: onDelete, child: const Text('Delete')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: state.filteredRoutes.length,
            itemBuilder: (context, index) {
              final route = state.filteredRoutes[index];
              return ListTile(
                dense: true,
                selected: route.routeId == state.selectedRouteId,
                leading: CircleAvatar(
                  backgroundColor: colorFromHex(route.colorHex),
                  radius: 10,
                ),
                title: Text('${route.routeCode} — ${route.routeName}'),
                subtitle: Text(
                  '${VehicleTypeMapping.displayName(route.vehicleType)}'
                  '${route.activeStatus ? '' : ' · Inactive'}',
                ),
                onTap: () => onSelect(route),
              );
            },
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.gesture),
          label: const Text('Draw new corridor'),
        ),
      ],
    );
  }
}

class _DrawPanel extends StatelessWidget {
  const _DrawPanel({
    required this.state,
    required this.onDrawTool,
    required this.onUndo,
    required this.onClear,
    required this.onFinishDrawing,
    required this.onCancel,
    this.onSave,
  });

  final ManageRoutesState state;
  final ValueChanged<RouteDrawTool> onDrawTool;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onFinishDrawing;
  final VoidCallback onCancel;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '1. Draw the road path',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          state.drawTool == RouteDrawTool.brush
              ? 'Press and slide your finger along the streets. The line snaps to real roads.'
              : 'Tap points along the route. Each segment follows the road network.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<RouteDrawTool>(
          segments: const [
            ButtonSegment(
              value: RouteDrawTool.brush,
              label: Text('Brush'),
              icon: Icon(Icons.gesture, size: 18),
            ),
            ButtonSegment(
              value: RouteDrawTool.pin,
              label: Text('Pin points'),
              icon: Icon(Icons.push_pin_outlined, size: 18),
            ),
          ],
          selected: {state.drawTool},
          onSelectionChanged: (s) => onDrawTool(s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          state.corridor.length < 2
              ? 'No path yet'
              : 'Path ready · ${state.corridor.length} points'
                  '${state.isBrushStrokeActive ? ' · drawing…' : ''}',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: state.waypoints.isEmpty && state.corridor.isEmpty ? null : onUndo,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
            OutlinedButton.icon(
              onPressed: state.corridor.isEmpty ? null : onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
            if (onSave == null)
              FilledButton.icon(
                onPressed: state.corridor.length < 2 ? null : onFinishDrawing,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Assign vehicle'),
              )
            else
              FilledButton.icon(
                onPressed: state.isSaving ? null : () => onSave!(),
                icon: state.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save path'),
              ),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  const _MetadataPanel({
    required this.state,
    required this.nameController,
    required this.codeController,
    required this.descriptionController,
    required this.baseFareController,
    required this.additionalFareController,
    required this.onVehicleType,
    required this.onColor,
    required this.onActive,
    required this.onContinueStops,
    required this.onCancel,
  });

  final ManageRoutesState state;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController descriptionController;
  final TextEditingController baseFareController;
  final TextEditingController additionalFareController;
  final ValueChanged<String> onVehicleType;
  final ValueChanged<String> onColor;
  final ValueChanged<bool> onActive;
  final VoidCallback onContinueStops;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final preset = VehicleRoutePreset.forType(state.vehicleType);
    return ListView(
      children: [
        Text('2. Which vehicle uses this road?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The drawn corridor becomes the official path for the vehicle you pick.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in VehicleRoutePreset.all)
              ChoiceChip(
                selected: state.vehicleType == v.value,
                label: Text(v.label),
                avatar: CircleAvatar(
                  backgroundColor: colorFromHex(v.colorHex),
                  radius: 8,
                ),
                onSelected: (_) => onVehicleType(v.value),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(preset.hint, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Route code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Route name',
            hintText: 'e.g. ${preset.label} Libertad Loop',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: baseFareController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Base fare',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: additionalFareController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Additional / km',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: descriptionController,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active for passengers'),
          subtitle: const Text('Inactive routes stay hidden from directions'),
          value: state.activeStatus,
          onChanged: onActive,
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onContinueStops,
                child: const Text('Review stops'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

class _StopsPanel extends StatelessWidget {
  const _StopsPanel({
    required this.state,
    required this.onStopName,
    required this.onRemoveStop,
    required this.onRegenerateStops,
    required this.onSave,
    required this.onCancel,
  });

  final ManageRoutesState state;
  final void Function(int index, String name) onStopName;
  final ValueChanged<int> onRemoveStop;
  final VoidCallback onRegenerateStops;
  final Future<void> Function() onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('3. Boarding stops', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Stops were suggested along your drawn path. Tap the map to add more, or rename below.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onRegenerateStops,
            icon: const Icon(Icons.alt_route),
            label: const Text('Re-suggest along path'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.draftStops.length,
            itemBuilder: (context, index) {
              final stop = state.draftStops[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(child: Text('${stop.order}')),
                title: TextFormField(
                  key: ValueKey('stop-${stop.order}-${stop.point.latitude}'),
                  initialValue: stop.name,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'Stop name',
                  ),
                  onChanged: (v) => onStopName(index, v),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemoveStop(index),
                ),
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: state.isSaving ? null : () => onSave(),
                icon: state.isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  'Save ${VehicleTypeMapping.displayName(state.vehicleType)} route',
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}
