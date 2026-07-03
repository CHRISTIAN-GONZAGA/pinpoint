import 'dart:async';
import 'dart:math' as math;

import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/explore/data/places_asset_datasource.dart';
import 'package:pinpoint/features/explore/data/places_local_datasource.dart';
import 'package:pinpoint/features/explore/data/places_remote_datasource.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Repository for tourism and establishment data with offline-first support.
class PlacesRepository {
  PlacesRepository({
    required PlacesRemoteDataSource remote,
    required PlacesLocalDataSource local,
    required PlacesAssetDataSource assets,
  })  : _remote = remote,
        _local = local,
        _assets = assets;

  final PlacesRemoteDataSource _remote;
  final PlacesLocalDataSource _local;
  final PlacesAssetDataSource _assets;
  List<Place>? _cachedAttractions;

  static const _apiTimeout = Duration(seconds: 8);

  Future<List<Place>> getAttractions({String? category, bool refresh = false}) async {
    if (!refresh && category == null && _cachedAttractions != null) {
      return _cachedAttractions!;
    }

    final local = await _safeLocalAttractions(category: category);
    if (local.isNotEmpty && !refresh) {
      if (category == null) _cachedAttractions = local;
      return local;
    }

    if (!AppConstants.offlineFirstMode) {
      final remote = await _tryRemote(
        () => _remote.fetchAttractions(category: category),
      );
      if (remote.isNotEmpty) {
        if (category == null) _cachedAttractions = remote;
        return remote;
      }
    }

    if (local.isNotEmpty) return local;

    final bundled = await _assets.getAttractions(category: category);
    if (category == null) _cachedAttractions = bundled;
    return bundled;
  }

  Future<Place> getAttraction(int id) async {
    final local = await _local.getAttraction(id);
    if (local != null) return local;

    if (!AppConstants.offlineFirstMode) {
      try {
        return await _remote.fetchAttraction(id).timeout(_apiTimeout);
      } catch (_) {}
    }

    for (final place in await _assets.getAttractions()) {
      if (place.id == id) return place;
    }
    throw StateError('Attraction $id not found');
  }

  Future<Place> getEstablishment(int id) async {
    final local = await _local.getEstablishment(id);
    if (local != null) return local;

    if (!AppConstants.offlineFirstMode) {
      try {
        return await _remote.fetchEstablishment(id).timeout(_apiTimeout);
      } catch (_) {}
    }

    for (final place in await _assets.getEstablishments()) {
      if (place.id == id) return place;
    }
    throw StateError('Establishment $id not found');
  }

  Future<List<Place>> getByCategory(String category) async {
    if (category == 'attractions' || category == 'museum' || category == 'park') {
      final cat = category == 'attractions' ? null : category;
      return getAttractions(category: cat);
    }

    final local = await _safeLocalEstablishments(category: category);
    if (local.isNotEmpty) return local;

    if (!AppConstants.offlineFirstMode) {
      final remote = await _tryRemote(
        () => _remote.fetchEstablishments(category: category),
      );
      if (remote.isNotEmpty) return remote;
    }

    return _assets.getEstablishments(category: category);
  }

  Future<List<Place>> search(String query) async {
    if (AppConstants.offlineFirstMode) {
      return _local.search(query);
    }
    try {
      return await _remote.search(query).timeout(_apiTimeout);
    } catch (_) {
      final local = await _local.search(query);
      if (local.isNotEmpty) return local;
      final needle = query.toLowerCase().trim();
      if (needle.isEmpty) return [];
      final all = [
        ...await _assets.getAttractions(),
        ...await _assets.getEstablishments(),
      ];
      return all
          .where(
            (place) =>
                place.name.toLowerCase().contains(needle) ||
                (place.address?.toLowerCase().contains(needle) ?? false),
          )
          .toList();
    }
  }

  Future<List<Place>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    if (!AppConstants.offlineFirstMode) {
      final remote = await _tryRemote(
        () => _remote.fetchNearby(lat: lat, lng: lng, radiusKm: radiusKm),
      );
      if (remote.isNotEmpty) return remote;
    }

    final local = await _local.getNearby(lat: lat, lng: lng, radiusKm: radiusKm);
    if (local.isNotEmpty) return local;

    final all = [
      ...await _assets.getAttractions(),
      ...await _assets.getEstablishments(),
    ];
    return _filterNearby(all, lat: lat, lng: lng, radiusKm: radiusKm);
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final local = await _local.getEmergencyContacts();
    if (local.isNotEmpty && AppConstants.offlineFirstMode) return local;

    if (!AppConstants.offlineFirstMode) {
      try {
        final remote =
            await _remote.fetchEmergencyContacts().timeout(_apiTimeout);
        if (remote.isNotEmpty) return remote;
      } catch (_) {}
    }

    if (local.isNotEmpty) return local;
    return _assets.getEmergencyContacts();
  }

  Future<List<Place>> _safeLocalAttractions({String? category}) async {
    try {
      return await _local.getAttractions(category: category);
    } catch (_) {
      return [];
    }
  }

  Future<List<Place>> _safeLocalEstablishments({String? category}) async {
    try {
      return await _local.getEstablishments(category: category);
    } catch (_) {
      return [];
    }
  }

  Future<List<Place>> _tryRemote(Future<List<Place>> Function() fetch) async {
    try {
      return await fetch().timeout(_apiTimeout);
    } catch (_) {
      return [];
    }
  }

  List<Place> _filterNearby(
    List<Place> places, {
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final withDistance = places.map((place) {
      final km = _haversineKm(lat, lng, place.latitude, place.longitude);
      return Place(
        id: place.id,
        name: place.name,
        placeType: place.placeType,
        latitude: place.latitude,
        longitude: place.longitude,
        category: place.category,
        description: place.description,
        address: place.address,
        entranceFee: place.entranceFee,
        openingHours: place.openingHours,
        contactInformation: place.contactInformation,
        distanceKm: km,
      );
    }).where((place) => (place.distanceKm ?? 0) <= radiusKm).toList();
    withDistance.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    return withDistance;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double value) => value * math.pi / 180;
}
