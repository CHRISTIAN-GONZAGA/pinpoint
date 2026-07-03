import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Forward and reverse geocoding for map search.
class GeocodingService {
  GeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Search places by query string within Butuan area.
  Future<List<MapLocation>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final response = await _dio.get<List<dynamic>>(
        '${AppConstants.nominatimBaseUrl}/search',
        queryParameters: {
          'q': '$query, Butuan City, Philippines',
          'format': 'json',
          'limit': 8,
          'countrycodes': 'ph',
        },
        options: Options(
          headers: {'User-Agent': 'PINPOINT-Butuan/0.1.0'},
        ),
      );
      final data = response.data ?? [];
      return data.map((item) {
        final map = item as Map<String, dynamic>;
        return MapLocation(
          latitude: double.parse(map['lat'] as String),
          longitude: double.parse(map['lon'] as String),
          label: map['display_name'] as String?,
        );
      }).toList();
    } catch (_) {
      throw const AppException('Unable to search locations. Check your connection.');
    }
  }

  /// Reverse geocode coordinates to a readable address.
  Future<String> reverseGeocode(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ].whereType<String>().where((p) => p.isNotEmpty).toList();
      return parts.isEmpty ? AppConstants.cityName : parts.join(', ');
    } catch (_) {
      return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
  }
}
