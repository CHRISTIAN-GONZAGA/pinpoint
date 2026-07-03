import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/explore/data/places_local_datasource.dart';
import 'package:pinpoint/features/explore/data/places_remote_datasource.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Repository for tourism and establishment data with offline-first support.
class PlacesRepository {
  PlacesRepository({
    required PlacesRemoteDataSource remote,
    required PlacesLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final PlacesRemoteDataSource _remote;
  final PlacesLocalDataSource _local;
  List<Place>? _cachedAttractions;

  Future<List<Place>> getAttractions({String? category, bool refresh = false}) async {
    if (AppConstants.offlineFirstMode) {
      return _local.getAttractions(category: category);
    }
    if (_cachedAttractions != null && !refresh && category == null) {
      return _cachedAttractions!;
    }
    try {
      final items = await _remote.fetchAttractions(category: category);
      if (category == null) _cachedAttractions = items;
      return items;
    } catch (_) {
      return _local.getAttractions(category: category);
    }
  }

  Future<Place> getAttraction(int id) async {
    if (AppConstants.offlineFirstMode) {
      final place = await _local.getAttraction(id);
      if (place != null) return place;
      throw StateError('Attraction $id not found');
    }
    try {
      return await _remote.fetchAttraction(id);
    } catch (_) {
      final place = await _local.getAttraction(id);
      if (place != null) return place;
      rethrow;
    }
  }

  Future<Place> getEstablishment(int id) async {
    if (AppConstants.offlineFirstMode) {
      final place = await _local.getEstablishment(id);
      if (place != null) return place;
      throw StateError('Establishment $id not found');
    }
    try {
      return await _remote.fetchEstablishment(id);
    } catch (_) {
      final place = await _local.getEstablishment(id);
      if (place != null) return place;
      rethrow;
    }
  }

  Future<List<Place>> getByCategory(String category) async {
    if (AppConstants.offlineFirstMode) {
      if (category == 'attractions' || category == 'museum' || category == 'park') {
        return _local.getAttractions(
          category: category == 'attractions' ? null : category,
        );
      }
      return _local.getEstablishments(category: category);
    }
    if (category == 'attractions' || category == 'museum' || category == 'park') {
      return _remote.fetchAttractions(category: category == 'attractions' ? null : category);
    }
    return _remote.fetchEstablishments(category: category);
  }

  Future<List<Place>> search(String query) async {
    if (AppConstants.offlineFirstMode) return _local.search(query);
    try {
      return await _remote.search(query);
    } catch (_) {
      return _local.search(query);
    }
  }

  Future<List<Place>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    if (AppConstants.offlineFirstMode) {
      return _local.getNearby(lat: lat, lng: lng, radiusKm: radiusKm);
    }
    try {
      return await _remote.fetchNearby(lat: lat, lng: lng, radiusKm: radiusKm);
    } catch (_) {
      return _local.getNearby(lat: lat, lng: lng, radiusKm: radiusKm);
    }
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    if (AppConstants.offlineFirstMode) return _local.getEmergencyContacts();
    try {
      return await _remote.fetchEmergencyContacts();
    } catch (_) {
      return _local.getEmergencyContacts();
    }
  }
}
