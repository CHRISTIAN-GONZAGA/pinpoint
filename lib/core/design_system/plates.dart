import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/core/theme/app_colors.dart';

/// Condensed route-number block used on plates, tickets, and ride rows.
class RouteCode extends StatelessWidget {
  const RouteCode({
    super.key,
    required this.code,
    this.color,
    this.size = RouteCodeSize.md,
  });

  final String code;
  final Color? color;
  final RouteCodeSize size;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    final dim = switch (size) {
      RouteCodeSize.sm => 26.0,
      RouteCodeSize.md => 36.0,
      RouteCodeSize.lg => 52.0,
    };
    final font = switch (size) {
      RouteCodeSize.sm => 12.0,
      RouteCodeSize.md => 15.0,
      RouteCodeSize.lg => 20.0,
    };
    final fg = AppColors.routeNeedsDarkInk(bg) ? AppColors.ink : Colors.white;
    return Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.edgeOf(Theme.of(context).brightness), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            code,
            maxLines: 1,
            style: GoogleFonts.archivoNarrow(
              color: fg,
              fontSize: font,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

enum RouteCodeSize { sm, md, lg }

/// Paper card with a 2px edge and a 1px inner pinstripe.
class PlateCard extends StatelessWidget {
  const PlateCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final edge = borderColor ?? AppColors.edgeOf(brightness);
    return Material(
      color: color ?? AppColors.paperOf(brightness),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: edge, width: 2),
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: edge.withValues(alpha: 0.18)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Yellow login band with a paper zigzag along the bottom.
class ZigzagEdge extends StatelessWidget {
  const ZigzagEdge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: AppColors.signal,
          child: child,
        ),
        CustomPaint(
          painter: _ZigzagPainter(
            color: AppColors.signal,
            paper: AppColors.stageOf(Theme.of(context).brightness),
          ),
          child: const SizedBox(height: 14, width: double.infinity),
        ),
      ],
    );
  }
}

class _ZigzagPainter extends CustomPainter {
  _ZigzagPainter({required this.color, required this.paper});

  final Color color;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()..moveTo(0, 0);
    const tooth = 14.0;
    for (var x = 0.0; x < size.width; x += tooth) {
      path.lineTo(x + tooth / 2, size.height);
      path.lineTo(x + tooth, 0);
    }
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = paper,
    );
  }

  @override
  bool shouldRepaint(covariant _ZigzagPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.paper != paper;
}
