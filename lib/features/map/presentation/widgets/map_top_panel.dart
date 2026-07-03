import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_pin_bar.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_route_filter_bar.dart';
import 'package:pinpoint/features/map/presentation/widgets/map_search_bar.dart';

/// Collapsible top overlay — keeps the map visible when folded.
class MapTopPanel extends ConsumerStatefulWidget {
  const MapTopPanel({
    super.key,
    required this.searchController,
    required this.expanded,
    required this.onExpandedChanged,
    required this.showRouteFilters,
    required this.onShowRouteFiltersChanged,
  });

  final TextEditingController searchController;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final bool showRouteFilters;
  final ValueChanged<bool> onShowRouteFiltersChanged;

  @override
  ConsumerState<MapTopPanel> createState() => _MapTopPanelState();
}

class _MapTopPanelState extends ConsumerState<MapTopPanel> {
  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Material(
            elevation: widget.expanded ? 6 : 3,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: theme.colorScheme.surface.withValues(alpha: 0.96),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderRow(
                  expanded: widget.expanded,
                  destinationLabel: mapState.destinationAddress,
                  onToggle: () => widget.onExpandedChanged(!widget.expanded),
                ),
                if (widget.expanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: MapSearchBar(
                      controller: widget.searchController,
                      onChanged: notifier.searchPlaces,
                      onClear: () {
                        widget.searchController.clear();
                        notifier.clearSearch();
                      },
                      isSearching: mapState.isSearching,
                      results: mapState.searchResults,
                      onSelect: (loc) {
                        widget.searchController.text = loc.label ?? 'Destination';
                        notifier.selectDestination(loc);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: MapPinBar(),
                  ),
                  if (mapState.featuredDestinations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _FeaturedDestinationsRow(
                      destinations: mapState.featuredDestinations,
                      selectedName: mapState.destinationAddress,
                      onTap: (dest) => notifier.selectFeaturedDestination(dest),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        Text(
                          'Jeepney routes',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              widget.onShowRouteFiltersChanged(!widget.showRouteFilters),
                          icon: Icon(
                            widget.showRouteFilters
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                          ),
                          label: Text(widget.showRouteFilters ? 'Hide' : 'Show'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.showRouteFilters)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: MapRouteFilterBar(),
                    ),
                  if (mapState.pinMode != MapPinMode.none)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        mapState.pinMode == MapPinMode.origin
                            ? 'Tap the map to set your start point'
                            : 'Tap the map to set your destination',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (mapState.locationWarning != null)
                    _InlineBanner(
                      icon: Icons.location_searching_rounded,
                      message: mapState.locationWarning!,
                      actionLabel: 'Fix',
                      onAction: notifier.openLocationSettings,
                    ),
                  if (mapState.transportWarning != null)
                    _InlineBanner(
                      icon: Icons.directions_bus_outlined,
                      message: mapState.transportWarning!,
                      actionLabel: 'Retry',
                      onAction: notifier.initialize,
                    ),
                  if (mapState.tilesUnavailable)
                    const _InlineBanner(
                      icon: Icons.map_outlined,
                      message: 'Map tiles unavailable. Check your internet connection.',
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.expanded,
    required this.destinationLabel,
    required this.onToggle,
  });

  final bool expanded;
  final String? destinationLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = destinationLabel ?? 'Search or pick a popular place';

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_up_rounded : Icons.search_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expanded ? 'Route tools' : 'Where to?',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (!expanded)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: expanded ? 'Hide tools' : 'Show tools',
              visualDensity: VisualDensity.compact,
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.unfold_less_rounded : Icons.tune_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedDestinationsRow extends StatelessWidget {
  const _FeaturedDestinationsRow({
    required this.destinations,
    required this.onTap,
    this.selectedName,
  });

  final List<FeaturedDestination> destinations;
  final ValueChanged<FeaturedDestination> onTap;
  final String? selectedName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Popular places',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: destinations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final dest = destinations[index];
              final selected = selectedName != null &&
                  (selectedName == dest.place.name ||
                      selectedName!.contains(dest.shortLabel));
              final color = PlaceUtils.colorForCategory(dest.place.category);
              return ActionChip(
                avatar: Icon(
                  PlaceUtils.iconForCategory(dest.place.category),
                  size: 16,
                  color: selected ? Colors.white : color,
                ),
                label: Text(dest.shortLabel),
                backgroundColor: selected ? color : color.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(color: color.withValues(alpha: selected ? 1 : 0.35)),
                onPressed: () => onTap(dest),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: Theme.of(context).textTheme.bodySmall),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ),
      ),
    );
  }
}
