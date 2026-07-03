import 'package:dio/dio.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/core/networking/api_client.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Remote API for tourism, establishments, and emergency data.
class PlacesRemoteDataSource {
  PlacesRemoteDataSource({required ApiClient apiClient}) : _api = apiClient.dio;

  final Dio _api;

  Future<List<Place>> fetchAttractions({String? category}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/tourism',
      queryParameters: category != null ? {'category': category} : null,
    );
    final list = response.data?['attractions'] as List<dynamic>? ?? [];
    return list.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Place> fetchAttraction(int id) async {
    final response = await _api.get<Map<String, dynamic>>('/tourism/$id');
    final data = response.data;
    if (data == null) throw const AppException('Attraction not found');
    return Place.fromJson(data);
  }

  Future<List<Place>> fetchEstablishments({String? category}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/establishments',
      queryParameters: category != null ? {'category': category} : null,
    );
    final list = response.data?['establishments'] as List<dynamic>? ?? [];
    return list.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Place> fetchEstablishment(int id) async {
    final response = await _api.get<Map<String, dynamic>>('/establishments/$id');
    final data = response.data;
    if (data == null) throw const AppException('Establishment not found');
    return Place.fromJson(data);
  }

  Future<List<Place>> fetchNearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/tourism/nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radiusKm},
    );
    final list = response.data?['places'] as List<dynamic>? ?? [];
    return list.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Place>> search(String query) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/tourism/search',
      queryParameters: {'q': query},
    );
    final data = response.data ?? {};
    final attractions = (data['attractions'] as List<dynamic>? ?? [])
        .map((e) => Place.fromJson(e as Map<String, dynamic>));
    final establishments = (data['establishments'] as List<dynamic>? ?? [])
        .map((e) => Place.fromJson(e as Map<String, dynamic>));
    return [...attractions, ...establishments];
  }

  Future<List<EmergencyContact>> fetchEmergencyContacts() async {
    final response = await _api.get<Map<String, dynamic>>('/emergency');
    final list = response.data?['contacts'] as List<dynamic>? ?? [];
    return list
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FavoriteItem>> fetchFavorites() async {
    final response = await _api.get<Map<String, dynamic>>('/favorites');
    final list = response.data?['favorites'] as List<dynamic>? ?? [];
    return list
        .map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteItem> addFavorite(Map<String, dynamic> payload) async {
    final response = await _api.post<Map<String, dynamic>>('/favorites', data: payload);
    final data = response.data;
    if (data == null) throw const AppException('Failed to save favorite');
    return FavoriteItem.fromJson(data);
  }

  Future<void> deleteFavorite(int favoriteId) async {
    await _api.delete<void>('/favorites/$favoriteId');
  }

  Future<List<HistoryItem>> fetchHistory() async {
    final response = await _api.get<Map<String, dynamic>>('/history');
    final list = response.data?['history'] as List<dynamic>? ?? [];
    return list.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<HistoryItem> addHistory(Map<String, dynamic> payload) async {
    final response = await _api.post<Map<String, dynamic>>('/history', data: payload);
    final data = response.data;
    if (data == null) throw const AppException('Failed to save history');
    return HistoryItem.fromJson(data);
  }

  Future<void> deleteHistory(int historyId) async {
    await _api.delete<void>('/history/$historyId');
  }

  Future<void> clearHistory() async {
    await _api.delete<void>('/history');
  }
}
