import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';
import 'package:pinpoint/core/utilities/place_utils.dart';
import 'package:pinpoint/features/explore/domain/place_models.dart';

/// Minimal place row for lists — restrained, readable.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.trailing,
    this.onFavorite,
    this.isFavorite = false,
  });

  final Place place;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final icon = PlaceUtils.iconForCategory(place.category);

    return Material(
      color: PremiumTokens.elevatedSurface(context),
      borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
            border: Border.all(color: PremiumTokens.separator(context), width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PremiumTokens.subtleFill(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: theme.textTheme.titleSmall?.copyWith(letterSpacing: -0.2),
                    ),
                    if (place.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                    if (place.distanceLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.distanceLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onFavorite != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? const Color(0xFFFF3B30) : null,
                    size: 22,
                  ),
                ),
              if (trailing != null)
                trailing!
              else if (onFavorite == null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
