import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Compact floating header — search + quick destination chips.
class MapMinimalHeader extends ConsumerWidget {
  const MapMinimalHeader({
    super.key,
    required this.searchController,
    required this.onOpenTools,
  });

  final TextEditingController searchController;
  final VoidCallback onOpenTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? const Color(0xFF1A2744).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.96);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              elevation: 1,
              shadowColor: Colors.black12,
              borderRadius: BorderRadius.circular(28),
              color: surface,
              child: TextField(
                controller: searchController,
                onChanged: notifier.searchPlaces,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Where to?',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    tooltip: 'Start, destination & routes',
                    onPressed: onOpenTools,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (mapState.isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (mapState.searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mapState.searchResults.length.clamp(0, 4),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = mapState.searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 20),
                      title: Text(
                        result.label ?? 'Location',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        searchController.text = result.label ?? 'Destination';
                        notifier.selectDestination(result);
                      },
                    );
                  },
                ),
              ),
            if (mapState.featuredDestinations.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mapState.featuredDestinations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final dest = mapState.featuredDestinations[index];
                    final color = PlaceUtils.colorForCategory(dest.place.category);
                    final selected = mapState.destinationAddress != null &&
                        (mapState.destinationAddress == dest.place.name ||
                            mapState.destinationAddress!.contains(dest.shortLabel));
                    return FilterChip(
                      label: Text(dest.shortLabel),
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        PlaceUtils.iconForCategory(dest.place.category),
                        size: 14,
                        color: selected ? Colors.white : color,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : null,
                      ),
                      backgroundColor: selected ? color : color.withValues(alpha: 0.12),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => notifier.selectFeaturedDestination(dest),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
