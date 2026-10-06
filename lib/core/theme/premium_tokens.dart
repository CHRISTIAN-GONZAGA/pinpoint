import 'package:flutter/material.dart';
import 'package:pinpoint/core/theme/app_colors.dart';

/// Surface tokens mapped to the route-plate palette.
abstract final class PremiumTokens {
  static Color groupedBackground(BuildContext context) =>
      AppColors.stageOf(Theme.of(context).brightness);

  static Color elevatedSurface(BuildContext context) =>
      AppColors.paperOf(Theme.of(context).brightness);

  static Color separator(BuildContext context) =>
      AppColors.hairlineOf(Theme.of(context).brightness);

  static Color subtleFill(BuildContext context) =>
      AppColors.sunkenOf(Theme.of(context).brightness);

  static Color inkMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52);
  }

  static const double surfaceRadius = 16;
  static const double pillRadius = 18;
  static const double navBarRadius = 22;
}
