import 'package:flutter/material.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/routing/domain/transport_colors.dart';

/// Color legend for active route segments on the map.
class MapRouteLegend extends StatelessWidget {
  const MapRouteLegend({super.key, required this.route});

  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final items = _legendItems();
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Material(
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      color: isDark
          ? const Color(0xFF152238).withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.97),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Your route',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${route.estimatedFare.toStringAsFixed(0)} PHP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  _LegendRow(index: entry.key + 1, item: entry.value),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 9, top: 2, bottom: 2),
                      child: Row(
                        children: [
                          Container(width: 2, height: 10, color: Colors.grey.withValues(alpha: 0.35)),
                          const SizedBox(width: 8),
                          Text('then', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  List<_LegendItem> _legendItems() {
    final items = <_LegendItem>[];
    final seen = <String>{};

    for (final step in route.steps) {
      if (step.distanceMeters <= 0) continue;
      if (step.type == RouteStepType.walk && step.instruction.contains('arrived')) {
        continue;
      }

      final key = step.type == RouteStepType.jeepney
          ? 'jeep-${step.routeCode}'
          : step.type.name;
      if (!seen.add(key)) continue;

      items.add(_LegendItem(
        type: step.type,
        label: _labelFor(step),
        color: _colorFor(step),
        distanceMeters: step.distanceMeters,
        durationLabel: step.durationLabel,
      ));
    }
    return items;
  }

  String _labelFor(RouteStep step) => switch (step.type) {
        RouteStepType.walk => 'Walk',
        RouteStepType.jeepney => step.routeCode ?? 'Jeepney',
        RouteStepType.modernJeepney => step.routeCode ?? 'Modern Jeepney',
        RouteStepType.bus => step.routeCode ?? 'Bus',
        RouteStepType.van => step.routeCode ?? 'Van',
        RouteStepType.tricycle => 'Tricycle',
        RouteStepType.taxi => 'Taxi',
        RouteStepType.transfer => 'Transfer',
      };

  Color _colorFor(RouteStep step) {
    if (step.segmentColorHex != null) {
      return colorFromHex(step.segmentColorHex!);
    }
    return switch (step.type) {
      RouteStepType.walk => TransportColors.walk,
      RouteStepType.tricycle => TransportColors.tricycle,
      RouteStepType.taxi => TransportColors.taxi,
      RouteStepType.transfer => TransportColors.transfer,
      RouteStepType.jeepney ||
      RouteStepType.modernJeepney ||
      RouteStepType.bus ||
      RouteStepType.van =>
        TransportColors.jeepney(step.routeCode),
    };
  }
}

class _LegendItem {
  const _LegendItem({
    required this.type,
    required this.label,
    required this.color,
    required this.distanceMeters,
    required this.durationLabel,
  });

  final RouteStepType type;
  final String label;
  final Color color;
  final double distanceMeters;
  final String durationLabel;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.index, required this.item});

  final int index;
  final _LegendItem item;

  @override
  Widget build(BuildContext context) {
    final isWalk = item.type == RouteStepType.walk;
    final dist = item.distanceMeters >= 1000
        ? '${(item.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${item.distanceMeters.round()} m';

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: item.color, width: 1.5),
          ),
          child: Text(
            '$index',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: item.color),
          ),
        ),
        const SizedBox(width: 8),
        Icon(_iconFor(item.type), size: 17, color: item.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '$dist · ${item.durationLabel}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
        _LineSwatch(color: item.color, dashed: isWalk),
      ],
    );
  }

  IconData _iconFor(RouteStepType type) => switch (type) {
        RouteStepType.walk => Icons.directions_walk_rounded,
        RouteStepType.jeepney ||
        RouteStepType.modernJeepney ||
        RouteStepType.bus ||
        RouteStepType.van =>
          Icons.directions_bus_filled_rounded,
        RouteStepType.tricycle => Icons.moped_rounded,
        RouteStepType.taxi => Icons.local_taxi_rounded,
        RouteStepType.transfer => Icons.swap_horiz_rounded,
      };
}

class _LineSwatch extends StatelessWidget {
  const _LineSwatch({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    if (dashed) {
      return Column(
        children: List.generate(3, (i) {
          return Container(
            width: 4,
            height: 3,
            margin: EdgeInsets.only(bottom: i < 2 ? 2 : 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      );
    }
    return Container(
      width: 28,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
    );
  }
}
