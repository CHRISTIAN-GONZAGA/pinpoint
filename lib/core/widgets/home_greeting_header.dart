import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/utilities/greeting_utils.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Editorial home greeting — typography-led, not a flashy AI gradient card.
class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({super.key, this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = GreetingUtils.initial(user: user);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GreetingUtils.dateLine().toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ).animate().fadeIn(duration: 280.ms),
                const SizedBox(height: 10),
                Text(
                  GreetingUtils.headline(user: user),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    height: 1.05,
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                ).animate(delay: 40.ms).fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
                const SizedBox(height: 8),
                Text(
                  GreetingUtils.subtitle(user: user),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PremiumTokens.inkMuted(context),
                    height: 1.4,
                  ),
                ).animate(delay: 80.ms).fadeIn(duration: 360.ms),
                const SizedBox(height: 14),
                Container(
                  width: 36,
                  height: 2.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                  ),
                ).animate(delay: 120.ms).fadeIn().scale(
                      begin: const Offset(0.25, 1),
                      end: const Offset(1, 1),
                      alignment: Alignment.centerLeft,
                    ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.12),
              ),
            ),
            child: Text(
              initial,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isDark ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ).animate(delay: 60.ms).fadeIn(duration: 320.ms),
        ],
      ),
    );
  }
}

/// Home section title with optional action.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.45,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PremiumTokens.inkMuted(context),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft empty-state card used on Home.
class HomeEmptyHint extends StatelessWidget {
  const HomeEmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTokens.elevatedSurface(context),
        borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
        border: Border.all(color: PremiumTokens.separator(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PremiumTokens.inkMuted(context),
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
