import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pinpoint/app/constants.dart';

/// Basemap tiles with Carto primary + Wikimedia fallback for mobile reliability.
class PinpointTileLayer extends StatelessWidget {
  const PinpointTileLayer({
    super.key,
    required this.isDark,
    this.onTileError,
  });

  final bool isDark;
  final void Function(Object error)? onTileError;

  static const _userAgent = 'PINPOINT-Butuan/2.0.0 (com.pinpoint.butuan.pinpoint)';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: isDark ? AppConstants.darkTileUrl : AppConstants.lightTileUrl,
      fallbackUrl: AppConstants.osmTileFallbackUrl,
      subdomains: AppConstants.mapTileSubdomains,
      userAgentPackageName: 'com.pinpoint.butuan.pinpoint',
      maxNativeZoom: 19,
      retinaMode: RetinaMode.isHighDensity(context),
      keepBuffer: 2,
      panBuffer: 1,
      tileProvider: NetworkTileProvider(
        headers: const {'User-Agent': _userAgent},
      ),
      errorTileCallback: (tile, error, stackTrace) => onTileError?.call(error),
    );
  }
}
