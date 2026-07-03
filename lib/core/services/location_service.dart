import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// GPS and location permission handling.
class LocationService {
  /// Returns true when location services are enabled and permission is granted.
  Future<bool> hasPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Requests location permission with user-friendly error mapping.
  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        'Location permission denied. Enable it in system settings.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const AppException('Location permission is required for navigation.');
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AppException('GPS is disabled. Please enable location services.');
    }
    return true;
  }

  /// Opens system settings when permission is permanently denied.
  Future<void> openSettings() => openAppSettings();

  /// Gets the current device position once.
  Future<MapLocation> getCurrentLocation() async {
    await requestPermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return MapLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
    );
  }

  /// Stream of position updates for live tracking.
  Stream<MapLocation> watchPosition() async* {
    await requestPermission();
    await for (final position in Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    )) {
      yield MapLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    }
  }
}
