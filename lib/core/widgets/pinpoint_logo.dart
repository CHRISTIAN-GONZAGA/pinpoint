import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinpoint/app/constants.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';

/// Animated PINPOINT logo used across splash and auth screens.
class PinpointLogo extends StatelessWidget {
  const PinpointLogo({
    super.key,
    this.size = 96,
    this.showTagline = false,
    this.pulsing = false,
    this.showTitle = true,
  });

  final double size;
  final bool showTagline;
  final bool pulsing;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    Widget logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.4),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 2),
      ),
      child: Icon(Icons.explore_rounded, color: Colors.white, size: size * 0.44),
    );

    if (pulsing) {
      logo = logo
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.97, 0.97),
            end: const Offset(1.03, 1.03),
            duration: 1400.ms,
            curve: Curves.easeInOut,
          );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        if (showTitle) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppConstants.appTagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
