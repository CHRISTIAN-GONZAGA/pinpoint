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

class _FeaturedDestinationMarkerState extends State<FeaturedDestinationMarker> {
  void _handleTap() => widget.onTap();

  @override
  Widget build(BuildContext context) {
    final color = PlaceUtils.colorForCategory(widget.destination.place.category);
    final selected = widget.isSelected;

    return GestureDetector(
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                widget.destination.shortLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          Transform.scale(
            scale: selected ? 1.25 : 1,
            child: CustomPaint(
              painter: _TeardropPainter(color),
              child: SizedBox(
                width: 28,
                height: 34,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Icon(
                    PlaceUtils.iconForCategory(widget.destination.place.category),
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  _TeardropPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..quadraticBezierTo(0, size.height * 0.55, size.width * 0.18, size.height * 0.28)
      ..arcToPoint(
        Offset(size.width * 0.82, size.height * 0.28),
        radius: Radius.circular(size.width * 0.45),
        clockwise: true,
      )
      ..quadraticBezierTo(size.width, size.height * 0.55, size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) => oldDelegate.color != color;
}
