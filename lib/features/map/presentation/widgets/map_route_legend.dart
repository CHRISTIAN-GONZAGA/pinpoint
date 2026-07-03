import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';

/// Color legend for active route segments on the map.
class MapRouteLegend extends StatelessWidget {
  const MapRouteLegend({super.key, required this.route});

  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final items = <_LegendItem>[];
    final seen = <RouteStepType>{};

    for (final segment in route.coloredSegments) {
      if (seen.contains(segment.type)) continue;
      seen.add(segment.type);
      items.add(_LegendItem(
        color: colorFromHex(segment.colorHex),
        label: _labelFor(segment),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: items.map((item) => _LegendRow(item: item)).toList(),
        ),
      ),
    );
  }

  String _labelFor(ColoredRouteSegment segment) => switch (segment.type) {
        RouteStepType.walk => 'Walk',
        RouteStepType.jeepney => segment.routeCode ?? 'Jeepney',
        RouteStepType.tricycle => 'Tricycle',
        RouteStepType.taxi => 'Taxi',
        RouteStepType.transfer => 'Transfer',
      };
}

class _LegendItem {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.item});
  final _LegendItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(item.label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}