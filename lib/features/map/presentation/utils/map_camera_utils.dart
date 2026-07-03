import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_camera_helper.dart';

/// Camera helpers for the interactive map.
abstract final class MapCameraUtils {
  static const _fitPadding = EdgeInsets.fromLTRB(48, 160, 48, 240);

  static void moveTo(MapController? controller, LatLng center, {double? zoom}) {
    MapCameraHelper.moveTo(controller, center, zoom: zoom);
  }

  static void fitPoints(
    MapController? controller,
    List<LatLng> points, {
    EdgeInsets padding = _fitPadding,
    double maxZoom = 16.5,
  }) {
    MapCameraHelper.fitPoints(
      controller,
      points,
      padding: padding,
      maxZoom: maxZoom,
    );
  }

  static void fitStep(
    MapController? controller,
    List<LatLng> polyline, {
    double zoom = 16,
  }) {
    MapCameraHelper.fitStep(controller, polyline, zoom: zoom);
  }
}
