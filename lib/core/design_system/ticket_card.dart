import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/core/theme/app_colors.dart';

/// Horizontal destination ticket: route stub, dashed cut, name, category, fare.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.title,
    required this.category,
    this.routeCode,
    this.routeColor,
    this.fareLabel,
    this.onTap,
  });

  final String title;
  final String category;
  final String? routeCode;
  final Color? routeColor;
  final String? fareLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final edge = AppColors.edgeOf(brightness);
    final ink = AppColors.inkOf(brightness);
    final muted = AppColors.inkSecondaryOf(brightness);
    final code = routeCode?.trim();
    final hasCode = code != null && code.isNotEmpty;
    final stub = routeColor ?? (hasCode ? AppColors.primaryFillOf(brightness) : AppColors.sunkenOf(brightness));
    final stubInk = hasCode
        ? (AppColors.routeNeedsDarkInk(stub) ? AppColors.ink : Colors.white)
        : muted;
    final fare = fareLabel?.trim();

    return SizedBox(
      width: 268,
      child: Material(
        color: AppColors.paperOf(brightness),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: edge, width: 2),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 62,
                    alignment: Alignment.center,
                    color: stub,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: hasCode
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              code,
                              maxLines: 1,
                              style: GoogleFonts.archivoNarrow(
                                color: stubInk,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          )
                        : Icon(Icons.place, color: stubInk, size: 26),
                  ),
                  CustomPaint(
                    painter: _TicketDashPainter(AppColors.stageOf(brightness)),
                    child: const SizedBox(width: 2),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.atkinsonHyperlegible(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.atkinsonHyperlegible(
                              fontSize: 14,
                              color: muted,
                            ),
                          ),
                          if (fare != null && fare.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              fare,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.archivoNarrow(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                color: ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketDashPainter extends CustomPainter {
  _TicketDashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 5.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketDashPainter oldDelegate) => oldDelegate.color != color;
}
