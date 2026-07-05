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

    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      color: isDark
          ? const Color(0xFF1A2744).withValues(alpha: 0.94)
          : Colors.white.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route guide',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 6),
                child: _LegendRow(
                  index: entry.key + 1,
                  item: entry.value,
                ),
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
        routeCode: step.routeCode,
      ));
    }
    return items;
  }

  String _labelFor(RouteStep step) => switch (step.type) {
        RouteStepType.walk => 'Walk',
        RouteStepType.jeepney => step.routeCode ?? 'Jeepney',
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
      RouteStepType.jeepney => TransportColors.jeepney(step.routeCode),
    };
  }
}

class _LegendItem {
  const _LegendItem({
    required this.type,
    required this.label,
    required this.color,
    this.routeCode,
  });

  final RouteStepType type;
  final String label;
  final Color color;
  final String? routeCode;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.index, required this.item});

  final int index;
  final _LegendItem item;

  @override
  Widget build(BuildContext context) {
    final isWalk = item.type == RouteStepType.walk;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: item.color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(_iconFor(item.type), size: 16, color: item.color),
        const SizedBox(width: 6),
        _LineSwatch(color: item.color, dashed: isWalk),
        const SizedBox(width: 8),
        Text(
          item.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  IconData _iconFor(RouteStepType type) => switch (type) {
        RouteStepType.walk => Icons.directions_walk_rounded,
        RouteStepType.jeepney => Icons.directions_bus_filled_rounded,
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
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Container(
            width: 5,
            height: 3,
            margin: EdgeInsets.only(right: i < 2 ? 2 : 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      );
    }
    return Container(
      width: 22,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
