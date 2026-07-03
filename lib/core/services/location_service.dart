import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:pinpoint/core/exceptions/app_exception.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// GPS and location permission handling.
class LocationService {
  static const _maxCacheAge = Duration(minutes: 15);

  /// Returns true when location services are enabled and permission is granted.
  Future<bool> hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Requests location permission with user-friendly error mapping.
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException(
        'GPS is off on your phone. Turn on Location in system settings, then tap Refresh.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        'PINPOINT needs location access. Open App Settings → Permissions → Location → Allow.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const AppException(
        'Location permission denied. Allow PINPOINT to use your location when prompted.',
      );
    }
    return true;
  }

  /// Opens app permission settings (use when permission is denied).
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Opens system location/GPS settings (use when GPS is disabled).
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens the most relevant settings screen for the current failure.
  Future<void> openRelevantSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await openLocationSettings();
      return;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return;
    }
    await openLocationSettings();
  }

  /// Gets the current device position once with retries and cache fallback.
  Future<MapLocation> getCurrentLocation() async {
    await requestPermission();

    final cached = await _freshLastKnownPosition();
    try {
      return await _fetchCurrentPosition(
        accuracy: LocationAccuracy.high,
        forceLocationManager: false,
        timeLimit: const Duration(seconds: 20),
      );
    } on TimeoutException {
      if (cached != null) return cached;
      try {
        return await _fetchCurrentPosition(
          accuracy: LocationAccuracy.medium,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 25),
        );
      } on TimeoutException {
        final last = await _anyLastKnownPosition();
        if (last != null) return last;
        throw const AppException(
          'Could not get a GPS fix. Go outdoors, wait a few seconds, then tap the location button.',
        );
      }
    } on LocationServiceDisabledException {
      throw const AppException(
        'GPS is off on your phone. Turn on Location in system settings.',
      );
    }
  }

  Future<MapLocation?> _freshLastKnownPosition() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final age = DateTime.now().difference(position.timestamp);
    if (age > _maxCacheAge) return null;
    return _toMapLocation(position);
  }

  Future<MapLocation?> _anyLastKnownPosition() async {
    final fused = await Geolocator.getLastKnownPosition();
    if (fused != null) return _toMapLocation(fused);
    final legacy = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
    if (legacy != null) return _toMapLocation(legacy);
    return null;
  }

  Future<MapLocation> _fetchCurrentPosition({
    required LocationAccuracy accuracy,
    required bool forceLocationManager,
    required Duration timeLimit,
  }) async {
    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: accuracy,
            timeLimit: timeLimit,
            forceLocationManager: forceLocationManager,
            intervalDuration: const Duration(seconds: 2),
          )
        : AppleSettings(
            accuracy: accuracy,
            timeLimit: timeLimit,
          );

    final position = await Geolocator.getCurrentPosition(locationSettings: settings);
    return _toMapLocation(position);
  }

  MapLocation _toMapLocation(Position position) => MapLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );

  /// Stream of position updates for live tracking.
  Stream<MapLocation> watchPosition() async* {
    await requestPermission();
    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 5),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );

    await for (final position in Geolocator.getPositionStream(locationSettings: settings)) {
      yield _toMapLocation(position);
    }
  }
}
