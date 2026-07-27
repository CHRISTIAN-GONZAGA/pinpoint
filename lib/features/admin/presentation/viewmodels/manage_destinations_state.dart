import 'package:latlong2/latlong.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';

enum ManageDestinationsMode {
  browse,
  placingPin,
  editing,
}

class AdminFeaturedDestination {
  const AdminFeaturedDestination({
    required this.destinationId,
    required this.name,
    required this.shortLabel,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.description,
    this.address,
    this.activeStatus = true,
    this.sortOrder = 0,
  });

  factory AdminFeaturedDestination.fromJson(Map<String, dynamic> json) {
    return AdminFeaturedDestination(
      destinationId: json['destination_id'] as int,
      name: json['name'] as String,
      shortLabel: json['short_label'] as String,
      category: json['category'] as String? ?? 'other',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
      address: json['address'] as String?,
      activeStatus: json['active_status'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  final int destinationId;
  final String name;
  final String shortLabel;
  final String category;
  final double latitude;
  final double longitude;
  final String? description;
  final String? address;
  final bool activeStatus;
  final int sortOrder;

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toCreatePayload() => {
        'name': name,
        'short_label': shortLabel,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (address != null && address!.isNotEmpty) 'address': address,
        'active_status': activeStatus,
        'sort_order': sortOrder,
      };

  Map<String, dynamic> toUpdatePayload() => toCreatePayload();
}

class ManageDestinationsState {
  const ManageDestinationsState({
    this.mode = ManageDestinationsMode.browse,
    this.destinations = const [],
    this.selectedDestinationId,
    this.draftPin,
    this.name = '',
    this.shortLabel = '',
    this.category = 'mall',
    this.description = '',
    this.address = '',
    this.activeStatus = true,
    this.sortOrder = 0,
    this.isLoading = false,
    this.isSaving = false,
    this.isSnapping = false,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  final ManageDestinationsMode mode;
  final List<AdminFeaturedDestination> destinations;
  final int? selectedDestinationId;
  final LatLng? draftPin;
  final String name;
  final String shortLabel;
  final String category;
  final String description;
  final String address;
  final bool activeStatus;
  final int sortOrder;
  final bool isLoading;
  final bool isSaving;
  final bool isSnapping;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  static const categories = CommonDestinations.destinationCategories;

  AdminFeaturedDestination? get selectedDestination {
    if (selectedDestinationId == null) return null;
    for (final item in destinations) {
      if (item.destinationId == selectedDestinationId) return item;
    }
    return null;
  }

  List<AdminFeaturedDestination> get filteredDestinations {
    final needle = searchQuery.trim().toLowerCase();
    if (needle.isEmpty) return destinations;
    return destinations
        .where(
          (d) =>
              d.name.toLowerCase().contains(needle) ||
              d.shortLabel.toLowerCase().contains(needle) ||
              d.category.toLowerCase().contains(needle),
        )
        .toList();
  }

  bool get canSave => draftPin != null && !isSaving;

  ManageDestinationsState copyWith({
    ManageDestinationsMode? mode,
    List<AdminFeaturedDestination>? destinations,
    int? selectedDestinationId,
    bool clearSelection = false,
    LatLng? draftPin,
    bool clearDraftPin = false,
    String? name,
    String? shortLabel,
    String? category,
    String? description,
    String? address,
    bool? activeStatus,
    int? sortOrder,
    bool? isLoading,
    bool? isSaving,
    bool? isSnapping,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ManageDestinationsState(
      mode: mode ?? this.mode,
      destinations: destinations ?? this.destinations,
      selectedDestinationId:
          clearSelection ? null : (selectedDestinationId ?? this.selectedDestinationId),
      draftPin: clearDraftPin ? null : (draftPin ?? this.draftPin),
      name: name ?? this.name,
      shortLabel: shortLabel ?? this.shortLabel,
      category: category ?? this.category,
      description: description ?? this.description,
      address: address ?? this.address,
      activeStatus: activeStatus ?? this.activeStatus,
      sortOrder: sortOrder ?? this.sortOrder,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSnapping: isSnapping ?? this.isSnapping,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}
