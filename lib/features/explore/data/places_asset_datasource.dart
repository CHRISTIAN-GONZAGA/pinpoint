import 'package:pinpoint/core/local/asset_loader.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Loads tourism and establishment data from bundled JSON assets.
class PlacesAssetDataSource {
  Future<List<Place>> getAttractions({String? category}) async {
    final raw = await AssetLoader.loadJsonList(AssetPaths.attractions, 'attractions');
    return _parsePlaces(raw, category: category);
  }

  Future<List<Place>> getEstablishments({String? category}) async {
    final raw = await AssetLoader.loadJsonList(AssetPaths.establishments, 'establishments');
    return _parsePlaces(raw, category: category);
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final raw = await AssetLoader.loadJsonList(AssetPaths.emergency, 'contacts');
    final contacts = <EmergencyContact>[];
    for (final item in raw) {
      try {
        contacts.add(EmergencyContact.fromJson(item));
      } catch (_) {}
    }
    return contacts;
  }

  List<Place> _parsePlaces(List<Map<String, dynamic>> raw, {String? category}) {
    final places = <Place>[];
    for (final item in raw) {
      try {
        final place = Place.fromJson(item);
        if (category == null || place.category == category) {
          places.add(place);
        }
      } catch (_) {}
    }
    return places;
  }
}
