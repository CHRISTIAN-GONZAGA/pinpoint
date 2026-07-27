import 'package:flutter/material.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/map/data/common_destinations.dart';

/// Category-colored featured pin with selection pulse.
class FeaturedDestinationMarker extends StatefulWidget {
  const FeaturedDestinationMarker({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final FeaturedDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<FeaturedDestinationMarker> createState() => _FeaturedDestinationMarkerState();
}

class _FeaturedDestinationMarkerState extends State<FeaturedDestinationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = Tween<double>(begin: 1, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant FeaturedDestinationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _pulse.forward(from: 0).then((_) => _pulse.reverse());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pulse.forward(from: 0).then((_) => _pulse.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = PlaceUtils.colorForCategory(widget.destination.place.category);
    final selected = widget.isSelected;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? color : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: selected ? 2.5 : 1),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? color.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.15),
                    blurRadius: selected ? 8 : 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                widget.destination.shortLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
            AnimatedScale(
              scale: selected ? 1.15 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                PlaceUtils.iconForCategory(widget.destination.place.category),
                color: color,
                size: selected ? 30 : 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
