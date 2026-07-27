import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/core/services/routing_service.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/manage_destinations_state.dart';

class ManageDestinationsNotifier extends Notifier<ManageDestinationsState> {
  RoutingService get _routing => ref.read(routingServiceProvider);

  @override
  ManageDestinationsState build() => const ManageDestinationsState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final raw = await ref.read(adminRepositoryProvider).getAdminDestinations();
      final destinations = raw.map(AdminFeaturedDestination.fromJson).toList();
      state = state.copyWith(isLoading: false, destinations: destinations);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void startCreate() {
    state = state.copyWith(
      mode: ManageDestinationsMode.placingPin,
      clearSelection: true,
      clearDraftPin: true,
      name: '',
      shortLabel: '',
      category: 'mall',
      description: '',
      address: '',
      activeStatus: true,
      sortOrder: state.destinations.length,
      clearError: true,
      clearSuccess: true,
    );
  }

  void cancelEditing() {
    state = state.copyWith(
      mode: ManageDestinationsMode.browse,
      clearDraftPin: true,
      clearError: true,
    );
  }

  void selectDestination(AdminFeaturedDestination destination) {
    state = state.copyWith(
      selectedDestinationId: destination.destinationId,
      mode: ManageDestinationsMode.browse,
      draftPin: destination.latLng,
      name: destination.name,
      shortLabel: destination.shortLabel,
      category: destination.category,
      description: destination.description ?? '',
      address: destination.address ?? '',
      activeStatus: destination.activeStatus,
      sortOrder: destination.sortOrder,
      clearError: true,
      clearSuccess: true,
    );
  }

  void startEditSelected() {
    if (state.selectedDestination == null) return;
    state = state.copyWith(mode: ManageDestinationsMode.editing, clearError: true);
  }

  Future<void> onMapTap(LatLng point) async {
    if (state.mode != ManageDestinationsMode.placingPin &&
        state.mode != ManageDestinationsMode.editing) {
      return;
    }
    state = state.copyWith(isSnapping: true, clearError: true);
    try {
      final snapped = await _routing.snapToNearestRoad(point);
      state = state.copyWith(
        isSnapping: false,
        draftPin: snapped,
        mode: ManageDestinationsMode.editing,
      );
    } catch (_) {
      state = state.copyWith(
        isSnapping: false,
        draftPin: point,
        mode: ManageDestinationsMode.editing,
      );
    }
  }

  void updateForm({
    String? name,
    String? shortLabel,
    String? category,
    String? description,
    String? address,
    bool? activeStatus,
    int? sortOrder,
  }) {
    state = state.copyWith(
      name: name ?? state.name,
      shortLabel: shortLabel ?? state.shortLabel,
      category: category ?? state.category,
      description: description ?? state.description,
      address: address ?? state.address,
      activeStatus: activeStatus ?? state.activeStatus,
      sortOrder: sortOrder ?? state.sortOrder,
    );
  }

  Future<bool> save() async {
    final pin = state.draftPin;
    if (pin == null || state.name.trim().isEmpty || state.shortLabel.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Set a pin, name, and chip label.');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    final payload = {
      'name': state.name.trim(),
      'short_label': state.shortLabel.trim(),
      'category': state.category,
      'latitude': pin.latitude,
      'longitude': pin.longitude,
      'description': state.description.trim(),
      'address': state.address.trim(),
      'active_status': state.activeStatus,
      'sort_order': state.sortOrder,
    };

    try {
      final repo = ref.read(adminRepositoryProvider);
      if (state.selectedDestinationId != null && state.mode == ManageDestinationsMode.editing) {
        await repo.updateDestination(state.selectedDestinationId!, payload);
      } else {
        await repo.createDestination(payload);
      }
      await load();
      state = state.copyWith(
        mode: ManageDestinationsMode.browse,
        clearDraftPin: true,
        isSaving: false,
        successMessage: 'Destination saved',
      );
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<bool> deleteSelected() async {
    final id = state.selectedDestinationId;
    if (id == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await ref.read(adminRepositoryProvider).deleteDestination(id);
      await load();
      state = state.copyWith(
        mode: ManageDestinationsMode.browse,
        clearSelection: true,
        clearDraftPin: true,
        isSaving: false,
        successMessage: 'Destination deleted',
      );
      return true;
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
      return false;
    }
  }
}

final manageDestinationsNotifierProvider =
    NotifierProvider<ManageDestinationsNotifier, ManageDestinationsState>(
  ManageDestinationsNotifier.new,
);
