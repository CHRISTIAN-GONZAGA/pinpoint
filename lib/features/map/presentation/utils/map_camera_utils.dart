import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Camera helpers for the interactive map.
abstract final class MapCameraUtils {
  static const _fitPadding = EdgeInsets.fromLTRB(48, 160, 48, 240);

  static void moveTo(MapController? controller, LatLng center, {double? zoom}) {
    if (controller == null) return;
    controller.move(center, zoom ?? controller.camera.zoom);
  }

  static void fitPoints(
    MapController? controller,
    List<LatLng> points, {
    EdgeInsets padding = _fitPadding,
    double maxZoom = 16.5,
  }) {
    if (controller == null || points.isEmpty) return;
    controller.fitCamera(
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
    if (controller == null || polyline.isEmpty) return;
    if (polyline.length == 1) {
      moveTo(controller, polyline.first, zoom: zoom);
      return;
    }
    fitPoints(controller, polyline, maxZoom: zoom);
  }
}
