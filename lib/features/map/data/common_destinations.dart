import 'package:pinpoint/features/explore/domain/place_models.dart';

/// A popular Butuan stop surfaced as a one-tap map destination.
class FeaturedDestination {
  const FeaturedDestination({
    required this.place,
    required this.shortLabel,
    this.destinationId,
  });

  final Place place;
  final String shortLabel;
  final int? destinationId;

  factory FeaturedDestination.fromApi(Map<String, dynamic> json) {
    final id = json['destination_id'] as int;
    return FeaturedDestination(
      destinationId: id,
      shortLabel: json['short_label'] as String,
      place: Place(
        id: id,
        name: json['name'] as String,
        placeType: 'featured',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        category: json['category'] as String?,
        description: json['description'] as String?,
        address: json['address'] as String?,
      ),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'destination_id': destinationId ?? place.id,
        'name': place.name,
        'short_label': shortLabel,
        'category': place.category,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'description': place.description,
        'address': place.address,
        'place_type': 'featured',
      };
}

/// Curated quick-pick destinations — offline fallback when API/cache is empty.
abstract final class CommonDestinations {
  /// `(placeType, id)` pairs — malls, landmarks, and key services in Butuan.
  static const featured = <({String type, int id, String shortLabel})>[
    (type: 'establishment', id: 1, shortLabel: 'Robinsons'),
    (type: 'establishment', id: 2, shortLabel: 'SM'),
    (type: 'establishment', id: 10, shortLabel: 'City Hall'),
    (type: 'establishment', id: 3, shortLabel: 'Hospital'),
    (type: 'establishment', id: 8, shortLabel: 'Almont Hotel'),
    (type: 'attraction', id: 3, shortLabel: 'Guingona Park'),
    (type: 'establishment', id: 9, shortLabel: 'Fopings'),
  ];

  static const destinationCategories = <String, String>{
    'mall': 'Malls',
    'hospital': 'Hospitals',
    'park': 'Parks',
    'hotel': 'Hotels',
    'school': 'Schools',
    'government': 'Government',
    'restaurant': 'Restaurants',
    'other': 'Other',
  };
}
