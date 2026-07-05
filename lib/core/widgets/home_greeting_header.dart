import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/greeting_utils.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Home dashboard greeting block with consistent typography.
class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({super.key, this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final icon = hour < 12
        ? Icons.wb_sunny_rounded
        : hour < 17
            ? Icons.wb_cloudy_rounded
            : Icons.nights_stay_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.secondary.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 26),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                GreetingUtils.headline(user: user),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              )
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .slideX(begin: -0.04, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 4),
              Text(
                GreetingUtils.subtitle(user: user),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  height: 1.35,
                ),
              ).animate(delay: 80.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ],
    );
  }
}
