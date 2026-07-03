import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/features/map/domain/map_models.dart';
import 'package:pinpoint/features/map/presentation/viewmodels/map_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quick actions for tagging start and destination on the map.
class MapPinBar extends ConsumerWidget {
  const MapPinBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapNotifierProvider);
    final notifier = ref.read(mapNotifierProvider.notifier);
    final pinMode = state.pinMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
          children: [
            _PinChip(
              icon: Icons.trip_origin,
              label: 'Start',
              isActive: pinMode == MapPinMode.origin,
              color: Theme.of(context).colorScheme.primary,
              subtitle: _shortLabel(state.currentAddress ?? 'Tap to set'),
              onTap: () => notifier.setPinMode(
                pinMode == MapPinMode.origin ? MapPinMode.none : MapPinMode.origin,
              ),
            ),
            IconButton(
              tooltip: 'Swap start and destination',
              onPressed: state.canGenerateRoute ? notifier.swapEndpoints : null,
              icon: const Icon(Icons.swap_vert_rounded, size: 20),
            ),
            _PinChip(
              icon: Icons.place_rounded,
              label: 'Destination',
              isActive: pinMode == MapPinMode.destination,
              color: Theme.of(context).colorScheme.error,
              subtitle: _shortLabel(state.destinationAddress ?? 'Tap to set'),
              onTap: () => notifier.setPinMode(
                pinMode == MapPinMode.destination
                    ? MapPinMode.none
                    : MapPinMode.destination,
              ),
            ),
          ],
        ),
    );
  }

  String _shortLabel(String text) {
    if (text.length <= 22) return text;
    return '${text.substring(0, 20)}…';
  }
}

class _PinChip extends StatelessWidget {
  const _PinChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isActive ? color : Colors.transparent,
              width: 2,
            ),
            color: isActive ? color.withValues(alpha: 0.08) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
