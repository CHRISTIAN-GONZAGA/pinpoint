import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:pinpoint/app/constants.dart';

/// Basemap tiles — Carto primary, OSM fallback, persistent Dio provider.
class PinpointTileLayer extends StatefulWidget {
  const PinpointTileLayer({
    super.key,
    required this.isDark,
    this.onTileError,
  });

  final bool isDark;
  final void Function(Object error)? onTileError;

  @override
  State<PinpointTileLayer> createState() => _PinpointTileLayerState();
}

class _PinpointTileLayerState extends State<PinpointTileLayer> {
  /// Reuse one provider so rebuilds do not cancel in-flight tile downloads.
  late final CancellableNetworkTileProvider _tileProvider =
      CancellableNetworkTileProvider(
    dioClient: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.bytes,
        headers: {
          'User-Agent':
              'PINPOINT-Butuan/${AppConstants.appVersion} (com.pinpoint.butuan.pinpoint)',
        },
      ),
    ),
  );

  @override
  void dispose() {
    _tileProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate:
          widget.isDark ? AppConstants.darkTileUrl : AppConstants.lightTileUrl,
      fallbackUrl: AppConstants.osmTileFallbackUrl,
      subdomains: AppConstants.mapTileSubdomains,
      userAgentPackageName: 'com.pinpoint.butuan.pinpoint',
      // High-DPI simulation can prevent tiles from appearing on some Android devices.
      retinaMode: false,
      maxNativeZoom: 19,
      keepBuffer: 3,
      panBuffer: 2,
      tileProvider: _tileProvider,
      errorTileCallback: (tile, error, stackTrace) =>
          widget.onTileError?.call(error),
    );
  }
}
