import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Safe [MapController] helpers — never throws before [FlutterMap] mounts.
abstract final class MapCameraHelper {
  static bool isReady(MapController? controller) {
    if (controller == null) return false;
    try {
      controller.camera;
      return true;
    } catch (_) {
      return false;
    }
  }

  static double zoom(MapController? controller, {double fallback = 14}) {
    if (!isReady(controller)) return fallback;
    return controller!.camera.zoom;
  }

  static double rotation(MapController? controller) {
    if (!isReady(controller)) return 0;
    return controller!.camera.rotation;
  }

  static void moveTo(
    MapController? controller,
    LatLng center, {
    double? zoom,
    double fallbackZoom = 14,
  }) {
    if (!isReady(controller)) return;
    controller!.move(center, zoom ?? controller.camera.zoom);
  }

  static void nudge(MapController? controller) {
    if (!isReady(controller)) return;
    final camera = controller!.camera;
    controller.move(camera.center, camera.zoom);
  }

  static void fitPoints(
    MapController? controller,
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.fromLTRB(48, 160, 48, 240),
    double maxZoom = 16.5,
  }) {
    if (!isReady(controller) || points.isEmpty) return;
    controller!.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: padding,
        maxZoom: maxZoom,
      ),
    );
  }

  static void fitStep(
    MapController? controller,
    List<LatLng> polyline, {
    double zoom = 16,
  }) {
    if (!isReady(controller) || polyline.isEmpty) return;
    if (polyline.length == 1) {
      moveTo(controller, polyline.first, zoom: zoom);
      return;
    }
    fitPoints(controller, polyline, maxZoom: zoom);
  }
}
