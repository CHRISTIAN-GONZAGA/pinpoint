import 'package:flutter/material.dart';

/// iOS-inspired layout and surface tokens for premium UI.
abstract final class PremiumTokens {
  static Color groupedBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  }

  static Color elevatedSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1C1C1E) : Colors.white;
  }

  static Color separator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
  }

  static Color subtleFill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
  }

  static const double surfaceRadius = 14;
  static const double pillRadius = 22;
  static const double navBarRadius = 20;
}
