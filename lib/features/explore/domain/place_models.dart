import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Unified place model for attractions and establishments.
class Place extends Equatable {
  const Place({
    required this.id,
    required this.name,
    required this.placeType,
    required this.latitude,
    required this.longitude,
    this.category,
    this.description,
    this.address,
    this.entranceFee,
    this.openingHours,
    this.contactInformation,
    this.distanceKm,
    this.verified = true,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final isAttraction = json['place_type'] == 'attraction' || json.containsKey('attraction_id');
    return Place(
      id: (json['attraction_id'] ?? json['establishment_id'] ?? json['id']) as int,
      name: json['name'] as String,
      placeType: isAttraction ? 'attraction' : 'establishment',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String?,
      description: json['description'] as String?,
      address: json['address'] as String?,
      entranceFee: json['entrance_fee'] as String?,
      openingHours: json['opening_hours'] as String?,
      contactInformation: json['contact_information'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      verified: json['verified'] as bool? ?? true,
    );
  }

  final int id;
  final String name;
  final String placeType;
  final double latitude;
  final double longitude;
  final String? category;
  final String? description;
  final String? address;
  final String? entranceFee;
  final String? openingHours;
  final String? contactInformation;
  final double? distanceKm;
  final bool verified;

  bool get hasVerifiedCoordinates => verified && latitude != 0 && longitude != 0;

  LatLng get latLng => LatLng(latitude, longitude);

  String get distanceLabel {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()} m';
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'place_type': placeType,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'description': description,
        'address': address,
        'entrance_fee': entranceFee,
        'opening_hours': openingHours,
        'contact_information': contactInformation,
        'verified': verified,
      };

  @override
  List<Object?> get props => [id, placeType, name];
}

/// Emergency agency contact.
class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.contactId,
    required this.agency,
    required this.hotline,
    required this.category,
    this.address,
    this.latitude,
    this.longitude,
    this.availability,
    this.instructions,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      contactId: json['contact_id'] as int,
      agency: json['agency'] as String,
      hotline: json['hotline'] as String,
      category: json['category'] as String,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      availability: json['availability'] as String?,
      instructions: json['instructions'] as String?,
    );
  }

  final int contactId;
  final String agency;
  final String hotline;
  final String category;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? availability;
  final String? instructions;

  @override
  List<Object?> get props => [contactId, agency];
}

/// Saved favorite place.
class FavoriteItem extends Equatable {
  const FavoriteItem({
    required this.id,
    required this.label,
    required this.placeType,
    this.placeId,
    this.latitude,
    this.longitude,
    this.category,
    this.createdAt,
    this.isLocal = false,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: (json['favorite_id'] ?? json['id']).toString(),
      label: json['label'] as String,
      placeType: json['place_type'] as String,
      placeId: json['place_id'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isLocal: json['is_local'] as bool? ?? false,
    );
  }

  factory FavoriteItem.fromPlace(Place place) {
    return FavoriteItem(
      id: 'local_${place.placeType}_${place.id}',
      label: place.name,
      placeType: place.placeType,
      placeId: place.id,
      latitude: place.latitude,
      longitude: place.longitude,
      category: place.category,
      createdAt: DateTime.now(),
      isLocal: true,
    );
  }

  final String id;
  final String label;
  final String placeType;
  final int? placeId;
  final double? latitude;
  final double? longitude;
  final String? category;
  final DateTime? createdAt;
  final bool isLocal;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'place_type': placeType,
        'place_id': placeId,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'created_at': createdAt?.toIso8601String(),
        'is_local': isLocal,
      };

  @override
  List<Object?> get props => [id, label];
}

/// Search or navigation history entry.
class HistoryItem extends Equatable {
  const HistoryItem({
    required this.id,
    required this.query,
    required this.searchType,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.isLocal = false,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: (json['history_id'] ?? json['id']).toString(),
      query: json['query'] as String,
      searchType: json['search_type'] as String? ?? 'place',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isLocal: json['is_local'] as bool? ?? false,
    );
  }

  final String id;
  final String query;
  final String searchType;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final bool isLocal;

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'search_type': searchType,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt?.toIso8601String(),
        'is_local': isLocal,
      };

  @override
  List<Object?> get props => [id, query];
}

/// Explore category definition.
class ExploreCategory {
  const ExploreCategory({
    required this.id,
    required this.label,
    required this.iconName,
    this.apiCategory,
  });

  final String id;
  final String label;
  final String iconName;
  final String? apiCategory;
}
