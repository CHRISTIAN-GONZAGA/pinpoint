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
  });

  final double size;
  final bool showTagline;
  final bool pulsing;

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
            color: AppColors.secondary.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.explore_rounded, color: Colors.white, size: size * 0.45),
          Positioned(
            bottom: size * 0.22,
            child: Icon(Icons.place_rounded, color: Colors.white, size: size * 0.28),
          ),
        ],
      ),
    );

    if (pulsing) {
      logo = logo
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.05, 1.05),
            duration: 1200.ms,
            curve: Curves.easeInOut,
          )
          .shimmer(duration: 1800.ms, color: Colors.white.withValues(alpha: 0.3));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(height: AppSpacing.md),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
        ),
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
