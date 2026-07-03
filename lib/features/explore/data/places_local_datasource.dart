import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Hive-backed cache for places and emergency contacts.
class PlacesLocalDataSource {
  Future<Box<dynamic>> get _box async => Hive.openBox(AppConstants.placesCacheBoxName);

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final box = await _box;
    final raw = box.get(key);
    if (raw is! List) return [];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Place>> getAttractions({String? category}) async {
    final items = await _readList('attractions');
    final places = items.map(Place.fromJson).toList();
    if (category == null) return places;
    return places.where((place) => place.category == category).toList();
  }

  Future<List<Place>> getEstablishments({String? category}) async {
    final items = await _readList('establishments');
    final places = items.map(Place.fromJson).toList();
    if (category == null) return places;
    return places.where((place) => place.category == category).toList();
  }

  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final items = await _readList('emergency');
    return items.map(EmergencyContact.fromJson).toList();
  }

  Future<List<Place>> getAllPlaces() async {
    return [...await getAttractions(), ...await getEstablishments()];
  }

  Future<List<Place>> search(String query) async {
    final needle = query.toLowerCase().trim();
    if (needle.isEmpty) return [];
    return (await getAllPlaces())
        .where(
          (place) =>
              place.name.toLowerCase().contains(needle) ||
              (place.address?.toLowerCase().contains(needle) ?? false) ||
              (place.category?.toLowerCase().contains(needle) ?? false),
        )
        .toList();
  }

  Future<List<Place>> getNearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    final all = await getAllPlaces();
    final withDistance = all.map((place) {
      final km = _distanceKm(lat, lng, place.latitude, place.longitude);
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

  Future<Place?> getAttraction(int id) async {
    for (final place in await getAttractions()) {
      if (place.id == id) return place;
    }
    return null;
  }

  Future<Place?> getEstablishment(int id) async {
    for (final place in await getEstablishments()) {
      if (place.id == id) return place;
    }
    return null;
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double value) => value * math.pi / 180;
}
