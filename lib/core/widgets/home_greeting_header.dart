import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/utilities/greeting_utils.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Home dashboard greeting — large title, calm typography.
class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({super.key, this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          GreetingUtils.headline(user: user),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 6),
        Text(
          GreetingUtils.subtitle(user: user),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ).animate(delay: 60.ms).fadeIn(duration: 350.ms),
      ],
    );
  }
}
