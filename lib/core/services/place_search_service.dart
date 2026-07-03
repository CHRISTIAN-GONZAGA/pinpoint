import 'package:pinpoint/core/services/geocoding_service.dart';
import 'package:pinpoint/features/explore/data/places_repository.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Merges bundled POI matches (shown first) with Nominatim address search.
class PlaceSearchService {
  PlaceSearchService({
    required PlacesRepository places,
    required GeocodingService geocoding,
  })  : _places = places,
        _geocoding = geocoding;

  final PlacesRepository _places;
  final GeocodingService _geocoding;

  Future<List<MapLocation>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final poiResults = <MapLocation>[];
    try {
      final places = await _places.search(trimmed);
      for (final place in places) {
        if (!place.hasVerifiedCoordinates) continue;
        poiResults.add(
          MapLocation(
            latitude: place.latitude,
            longitude: place.longitude,
            label: place.name,
          ),
        );
      }
    } catch (_) {}

    var nominatimResults = <MapLocation>[];
    try {
      nominatimResults = await _geocoding.searchPlaces(trimmed);
    } catch (_) {}

    final seen = <String>{};
    final merged = <MapLocation>[];
    for (final loc in [...poiResults, ...nominatimResults]) {
      final key = '${loc.latitude.toStringAsFixed(4)},${loc.longitude.toStringAsFixed(4)}';
      if (seen.add(key)) merged.add(loc);
      if (merged.length >= 8) break;
    }
    return merged;
  }
}
