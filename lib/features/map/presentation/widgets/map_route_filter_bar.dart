import 'package:flutter/material.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-select chips to show specific jeepney routes (R1–R7) on the map.
class MapRouteFilterBar extends ConsumerWidget {
  const MapRouteFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final routes = state.jeepneyRoutes;

    if (routes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Jeepney routes',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => notifier.showAllRoutes(),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () => notifier.clearRouteFilters(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: routes.map((route) {
                  final selected = state.visibleRouteCodes.contains(route.routeCode);
                  final color = colorFromHex(route.colorHex);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(route.routeCode),
                      selected: selected,
                      showCheckmark: true,
                      avatar: CircleAvatar(
                        backgroundColor: color,
                        radius: 8,
                      ),
                      onSelected: (_) => notifier.toggleRouteFilter(route.routeCode),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
    );
  }
}
