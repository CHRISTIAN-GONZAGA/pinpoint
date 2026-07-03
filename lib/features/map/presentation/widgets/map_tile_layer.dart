import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pinpoint/app/constants.dart';

/// Basemap tiles with Carto primary + OSM fallback for mobile reliability.
class PinpointTileLayer extends StatelessWidget {
  const PinpointTileLayer({
    super.key,
    required this.isDark,
    this.onTileError,
  });

  final bool isDark;
  final void Function(Object error)? onTileError;

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: isDark ? AppConstants.darkTileUrl : AppConstants.lightTileUrl,
      fallbackUrl: AppConstants.osmTileFallbackUrl,
      subdomains: AppConstants.mapTileSubdomains,
      userAgentPackageName: 'com.pinpoint.butuan',
      maxNativeZoom: 19,
      retinaMode: RetinaMode.isHighDensity(context),
      errorTileCallback: (tile, error, stackTrace) => onTileError?.call(error),
    );
  }
}
