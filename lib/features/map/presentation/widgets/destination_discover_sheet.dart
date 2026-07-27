import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';

/// Category-filtered bottom sheet to browse curated destinations on the map.
class DestinationDiscoverSheet extends StatefulWidget {
  const DestinationDiscoverSheet({
    super.key,
    required this.destinations,
    required this.onSelect,
  });

  final List<FeaturedDestination> destinations;
  final ValueChanged<FeaturedDestination> onSelect;

  static Future<void> show(
    BuildContext context, {
    required List<FeaturedDestination> destinations,
    required ValueChanged<FeaturedDestination> onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DestinationDiscoverSheet(
        destinations: destinations,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<DestinationDiscoverSheet> createState() => _DestinationDiscoverSheetState();
}

class _DestinationDiscoverSheetState extends State<DestinationDiscoverSheet> {
  var _category = 'all';
  var _query = '';

  List<FeaturedDestination> get _filtered {
    final needle = _query.trim().toLowerCase();
    return widget.destinations.where((dest) {
      final matchesCategory = _category == 'all' || dest.place.category == _category;
      if (!matchesCategory) return false;
      if (needle.isEmpty) return true;
      return dest.place.name.toLowerCase().contains(needle) ||
          dest.shortLabel.toLowerCase().contains(needle) ||
          (dest.place.address?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      ('all', 'All'),
      ...CommonDestinations.destinationCategories.entries.map((e) => (e.key, e.value)),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Browse places', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search destinations…',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final (id, label) = categories[index];
                    final selected = _category == id;
                    return FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = id),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No places match your filters.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final dest = _filtered[index];
                          final color = PlaceUtils.colorForCategory(dest.place.category);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(
                                PlaceUtils.iconForCategory(dest.place.category),
                                color: color,
                                size: 20,
                              ),
                            ),
                            title: Text(dest.place.name),
                            subtitle: Text(
                              dest.shortLabel,
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: const Icon(Icons.navigation_rounded),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelect(dest);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
