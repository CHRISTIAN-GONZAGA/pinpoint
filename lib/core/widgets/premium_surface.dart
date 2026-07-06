import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';

/// Grouped list surface — iOS Settings / Apple Health style.
class PremiumSurface extends StatelessWidget {
  const PremiumSurface({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.margin,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, thickness: 0.5, color: PremiumTokens.separator(context)));
      }
      items.add(children[i]);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: PremiumTokens.elevatedSurface(context),
        borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
        border: Border.all(color: PremiumTokens.separator(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: Column(mainAxisSize: MainAxisSize.min, children: items)),
    );
  }
}

/// Large title section header used on primary screens.
class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Compact overline for grouped sections.
class PremiumSectionLabel extends StatelessWidget {
  const PremiumSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
      ),
    );
  }
}

/// Tappable row inside a [PremiumSurface].
class PremiumListRow extends StatelessWidget {
  const PremiumListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: dense ? 10 : 14,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon tile for quick actions — restrained, not rainbow.
class PremiumActionTile extends StatelessWidget {
  const PremiumActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;

    return Material(
      color: PremiumTokens.elevatedSurface(context),
      borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
        child: Container(
          width: 108,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
            border: Border.all(color: PremiumTokens.separator(context), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
