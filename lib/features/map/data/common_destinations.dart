import 'package:pinpoint/features/explore/domain/place_models.dart';

/// A popular Butuan stop surfaced as a one-tap map destination.
class FeaturedDestination {
  const FeaturedDestination({
    required this.place,
    required this.shortLabel,
  });

  final Place place;
  final String shortLabel;
}

/// Curated quick-pick destinations for the map (loaded from bundled assets).
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
    (type: 'establishment', id: 13, shortLabel: '7-Eleven'),
  ];
}
