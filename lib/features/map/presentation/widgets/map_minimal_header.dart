import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';

/// Compact floating header — search + quick destination chips.
class MapMinimalHeader extends ConsumerWidget {
  const MapMinimalHeader({
    super.key,
    required this.searchController,
    required this.onOpenTools,
    this.onBrowseDestinations,
    this.compact = false,
  });

  final TextEditingController searchController;
  final VoidCallback onOpenTools;
  final VoidCallback? onBrowseDestinations;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surface = AppColors.paperOf(brightness);
    final edge = isDark ? AppColors.edgeDark : AppColors.edge;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar with glassmorphism + shadow
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: isDark ? 0.88 : 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: edge.withValues(alpha: isDark ? 0.5 : 1.0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: notifier.searchPlaces,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Where to?',
                      hintStyle: TextStyle(
                        color: AppColors.inkSecondaryOf(brightness),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.search_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: AppColors.inkSecondaryOf(brightness),
                        ),
                        tooltip: 'Start, destination and routes',
                        onPressed: onOpenTools,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
            if (mapState.isSearching)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(2),
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: AppColors.hairlineOf(brightness),
                ),
              ),
            if (mapState.searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: edge.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: mapState.searchResults.length.clamp(0, 4),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.hairlineOf(brightness),
                    ),
                    itemBuilder: (context, index) {
                      final result = mapState.searchResults[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            searchController.text = result.label ?? 'Destination';
                            notifier.selectDestination(result);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.place_rounded,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    result.label ?? 'Location',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.north_west_rounded,
                                  size: 14,
                                  color: AppColors.inkSecondaryOf(brightness).withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (!compact && mapState.featuredDestinations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onBrowseDestinations != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onBrowseDestinations,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Browse',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 36,
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
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: FilterChip(
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
                                color: selected ? Colors.white : AppColors.inkOf(brightness),
                              ),
                              backgroundColor: isDark
                                  ? color.withValues(alpha: 0.2)
                                  : color.withValues(alpha: 0.1),
                              selectedColor: color,
                              side: BorderSide(
                                color: selected ? color : color.withValues(alpha: 0.4),
                                width: selected ? 1.5 : 1,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => notifier.selectFeaturedDestination(dest),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
