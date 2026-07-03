import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';

/// Bottom sheet when tapping a featured destination marker on the map.
class FeaturedDestinationSheet extends StatelessWidget {
  const FeaturedDestinationSheet({
    super.key,
    required this.destination,
    required this.onNavigateTo,
    required this.onNavigateFrom,
  });

  final FeaturedDestination destination;
  final VoidCallback onNavigateTo;
  final VoidCallback onNavigateFrom;

  static Future<void> show(
    BuildContext context, {
    required FeaturedDestination destination,
    required VoidCallback onNavigateTo,
    required VoidCallback onNavigateFrom,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FeaturedDestinationSheet(
        destination: destination,
        onNavigateTo: onNavigateTo,
        onNavigateFrom: onNavigateFrom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = destination.place;
    final color = PlaceUtils.colorForCategory(place.category);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(PlaceUtils.iconForCategory(place.category), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: Theme.of(context).textTheme.titleMedium),
                    if (place.address != null)
                      Text(
                        place.address!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.65),
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onNavigateTo();
            },
            icon: const Icon(Icons.place_rounded),
            label: const Text('Set as destination'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onNavigateFrom();
            },
            icon: const Icon(Icons.trip_origin),
            label: const Text('Set as start'),
          ),
        ],
      ),
    );
  }
}
