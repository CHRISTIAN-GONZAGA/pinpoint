import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_destinations_notifier.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_destinations_state.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_tile_layer.dart';

/// Admin map flow: tap to pin a curated common destination.
class ManageDestinationsScreen extends ConsumerStatefulWidget {
  const ManageDestinationsScreen({super.key});

  @override
  ConsumerState<ManageDestinationsScreen> createState() =>
      _ManageDestinationsScreenState();
}

class _ManageDestinationsScreenState extends ConsumerState<ManageDestinationsScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _shortLabelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(manageDestinationsNotifierProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _shortLabelController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _sortOrderController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _syncFormFromState(ManageDestinationsState state) {
    if (_nameController.text != state.name) _nameController.text = state.name;
    if (_shortLabelController.text != state.shortLabel) {
      _shortLabelController.text = state.shortLabel;
    }
    if (_descriptionController.text != state.description) {
      _descriptionController.text = state.description;
    }
    if (_addressController.text != state.address) _addressController.text = state.address;
    final sort = state.sortOrder.toString();
    if (_sortOrderController.text != sort) _sortOrderController.text = sort;
  }

  void _pushForm(ManageDestinationsNotifier notifier) {
    notifier.updateForm(
      name: _nameController.text,
      shortLabel: _shortLabelController.text,
      description: _descriptionController.text,
      address: _addressController.text,
      sortOrder: int.tryParse(_sortOrderController.text) ?? 0,
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete destination?'),
        content: const Text('Passengers will no longer see this quick-pick place.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success =
        await ref.read(manageDestinationsNotifierProvider.notifier).deleteSelected();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(success ? 'Destination deleted' : 'Delete failed'),
        content: Text(
          success
              ? 'This place was removed from passenger quick-picks.'
              : 'Could not delete this destination. Try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manageDestinationsNotifierProvider);
    final notifier = ref.read(manageDestinationsNotifierProvider.notifier);
    final theme = Theme.of(context);
    final placing = state.mode == ManageDestinationsMode.placingPin ||
        state.mode == ManageDestinationsMode.editing;

    ref.listen(manageDestinationsNotifierProvider, (prev, next) {
      _syncFormFromState(next);
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: theme.colorScheme.error),
        );
      }
      if (next.successMessage != null &&
          next.successMessage != prev?.successMessage &&
          next.successMessage != 'Destination deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Destinations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (placing) {
              notifier.cancelEditing();
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (state.mode == ManageDestinationsMode.browse)
            TextButton.icon(
              onPressed: notifier.startCreate,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add'),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(AppConstants.butuanLat, AppConstants.butuanLng),
              initialZoom: AppConstants.defaultMapZoom,
              onTap: placing ? (_, point) => notifier.onMapTap(point) : null,
            ),
              children: [
                PinpointTileLayer(isDark: theme.brightness == Brightness.dark),
              MarkerLayer(
                markers: [
                  ...state.destinations.map((dest) {
                    final selected = dest.destinationId == state.selectedDestinationId;
                    final color = PlaceUtils.colorForCategory(dest.category);
                    return Marker(
                      point: dest.latLng,
                      width: 100,
                      height: 52,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () => notifier.selectDestination(dest),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: selected ? color : Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color, width: selected ? 2 : 1),
                              ),
                              child: Text(
                                dest.shortLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : color,
                                ),
                              ),
                            ),
                            Icon(PlaceUtils.iconForCategory(dest.category), color: color, size: 24),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (state.draftPin != null)
                    Marker(
                      point: state.draftPin!,
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.add_location_alt,
                        color: theme.colorScheme.primary,
                        size: 36,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (state.isSnapping)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(child: Chip(label: Text('Snapping to road…'))),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _BottomPanel(
              state: state,
              searchController: _searchController,
              nameController: _nameController,
              shortLabelController: _shortLabelController,
              descriptionController: _descriptionController,
              addressController: _addressController,
              sortOrderController: _sortOrderController,
              onSearchChanged: notifier.setSearchQuery,
              onCategoryChanged: (v) => notifier.updateForm(category: v),
              onActiveChanged: (v) => notifier.updateForm(activeStatus: v),
              onFieldsChanged: () => _pushForm(notifier),
              onEdit: notifier.startEditSelected,
              onSelect: notifier.selectDestination,
              onSave: () async {
                _pushForm(notifier);
                await notifier.save();
              },
              onDelete: _confirmDelete,
              onCancel: notifier.cancelEditing,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.searchController,
    required this.nameController,
    required this.shortLabelController,
    required this.descriptionController,
    required this.addressController,
    required this.sortOrderController,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onActiveChanged,
    required this.onFieldsChanged,
    required this.onEdit,
    required this.onSelect,
    required this.onSave,
    required this.onDelete,
    required this.onCancel,
  });

  final ManageDestinationsState state;
  final TextEditingController searchController;
  final TextEditingController nameController;
  final TextEditingController shortLabelController;
  final TextEditingController descriptionController;
  final TextEditingController addressController;
  final TextEditingController sortOrderController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onFieldsChanged;
  final VoidCallback onEdit;
  final ValueChanged<AdminFeaturedDestination> onSelect;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface.withValues(alpha: 0.97);

    if (state.mode == ManageDestinationsMode.placingPin) {
      return Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: surface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tap the map to place a pin', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'The pin snaps to the nearest road so routing works reliably.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ),
      );
    }

    if (state.mode == ManageDestinationsMode.editing) {
      return Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.selectedDestinationId == null ? 'New destination' : 'Edit destination',
                style: theme.textTheme.titleMedium,
              ),
              if (state.draftPin == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Tap the map to set location',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: nameController,
                onChanged: (_) => onFieldsChanged(),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: shortLabelController,
                onChanged: (_) => onFieldsChanged(),
                decoration: const InputDecoration(
                  labelText: 'Chip label',
                  hintText: 'Optional — defaults to the name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: state.category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ManageDestinationsState.categories.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onCategoryChanged(v);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: addressController,
                onChanged: (_) => onFieldsChanged(),
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descriptionController,
                onChanged: (_) => onFieldsChanged(),
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: sortOrderController,
                onChanged: (_) => onFieldsChanged(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sort order',
                  helperText: 'Lower numbers show first on Home & Map chips',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: state.activeStatus,
                onChanged: onActiveChanged,
              ),
              if (state.draftPin == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Save unlocks after you tap the map to place a pin.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.canSave ? onSave : null,
                      child: state.isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search destinations…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (state.filteredDestinations.isEmpty)
              const Text('No destinations yet. Tap Add to create one.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.filteredDestinations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final dest = state.filteredDestinations[index];
                    final selected = dest.destinationId == state.selectedDestinationId;
                    return ListTile(
                      selected: selected,
                      dense: true,
                      leading: Icon(
                        PlaceUtils.iconForCategory(dest.category),
                        color: PlaceUtils.colorForCategory(dest.category),
                      ),
                      title: Text(dest.name),
                      subtitle: Text('${dest.shortLabel} · ${dest.category}'),
                      trailing: dest.activeStatus
                          ? null
                          : const Text('Inactive', style: TextStyle(fontSize: 11)),
                      onTap: () => onSelect(dest),
                    );
                  },
                ),
              ),
            if (state.selectedDestination != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.isSaving ? null : onDelete,
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
