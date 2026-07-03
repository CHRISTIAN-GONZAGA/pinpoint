import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_pin_bar.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_route_filter_bar.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_search_bar.dart';

/// Full route tools — opened on demand from the minimal header.
class MapToolsSheet extends ConsumerWidget {
  const MapToolsSheet({
    super.key,
    required this.searchController,
  });

  final TextEditingController searchController;

  static Future<void> show(BuildContext context, TextEditingController searchController) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: MapToolsSheet(searchController: searchController),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        children: [
          Text('Route tools', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          MapSearchBar(
            controller: searchController,
            onChanged: notifier.searchPlaces,
            onClear: () {
              searchController.clear();
              notifier.clearSearch();
            },
            isSearching: mapState.isSearching,
            results: mapState.searchResults,
            onSelect: (loc) {
              searchController.text = loc.label ?? 'Destination';
              notifier.selectDestination(loc);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const MapPinBar(),
          const SizedBox(height: AppSpacing.md),
          const MapRouteFilterBar(),
          if (mapState.pinMode != MapPinMode.none) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              mapState.pinMode == MapPinMode.origin
                  ? 'Tap the map to set your start point'
                  : 'Tap the map to set your destination',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
