import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';

/// Google Maps-style actions when the user taps the map.
class MapContextSheet extends StatelessWidget {
  const MapContextSheet({
    super.key,
    required this.point,
    required this.address,
    this.nearestStopName,
    this.nearestStopDistanceM,
    required this.onNavigateFrom,
    required this.onNavigateTo,
    required this.onExploreNearby,
  });

  final LatLng point;
  final String address;
  final String? nearestStopName;
  final double? nearestStopDistanceM;
  final VoidCallback onNavigateFrom;
  final VoidCallback onNavigateTo;
  final VoidCallback onExploreNearby;

  static Future<void> show(
    BuildContext context, {
    required LatLng point,
    required String address,
    String? nearestStopName,
    double? nearestStopDistanceM,
    required VoidCallback onNavigateFrom,
    required VoidCallback onNavigateTo,
    required VoidCallback onExploreNearby,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MapContextSheet(
        point: point,
        address: address,
        nearestStopName: nearestStopName,
        nearestStopDistanceM: nearestStopDistanceM,
        onNavigateFrom: onNavigateFrom,
        onNavigateTo: onNavigateTo,
        onExploreNearby: onExploreNearby,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              address,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (nearestStopName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Nearest stop: $nearestStopName'
                '${nearestStopDistanceM != null ? ' (${nearestStopDistanceM!.round()} m)' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.trip_origin),
              title: const Text('Navigate from here'),
              subtitle: const Text('Set as start point'),
              onTap: () {
                Navigator.pop(context);
                onNavigateFrom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.place_rounded),
              title: const Text('Navigate to here'),
              subtitle: const Text('Set as destination'),
              onTap: () {
                Navigator.pop(context);
                onNavigateTo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('Explore nearby'),
              subtitle: const Text('Show places and stops around this point'),
              onTap: () {
                Navigator.pop(context);
                onExploreNearby();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Nearby summary shown on long-press.
class MapNearbySheet extends StatelessWidget {
  const MapNearbySheet({
    super.key,
    required this.items,
    required this.onNavigateFrom,
    required this.onNavigateTo,
  });

  final List<MapNearbyItem> items;
  final VoidCallback onNavigateFrom;
  final VoidCallback onNavigateTo;

  static Future<void> show(
    BuildContext context, {
    required List<MapNearbyItem> items,
    required VoidCallback onNavigateFrom,
    required VoidCallback onNavigateTo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MapNearbySheet(
        items: items,
        onNavigateFrom: onNavigateFrom,
        onNavigateTo: onNavigateTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nearby', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...items.map(
              (item) => ListTile(
                dense: true,
                leading: Icon(item.icon, color: item.color, size: 22),
                title: Text(item.label),
                subtitle: Text(item.subtitle),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onNavigateFrom();
                    },
                    icon: const Icon(Icons.trip_origin, size: 18),
                    label: const Text('From here'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onNavigateTo();
                    },
                    icon: const Icon(Icons.place_rounded, size: 18),
                    label: const Text('To here'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MapNearbyItem {
  const MapNearbyItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
}
