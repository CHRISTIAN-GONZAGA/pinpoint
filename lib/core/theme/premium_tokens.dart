import 'package:flutter/material.dart';

/// Surface and layout tokens — restrained luxury, navy/teal brand.
abstract final class PremiumTokens {
  static Color groupedBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Cool stone — not flat iOS grey, not warm cream AI-slop.
    return isDark ? const Color(0xFF0B0F14) : const Color(0xFFF3F5F8);
  }

  static Color elevatedSurface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF161B22) : const Color(0xFFFAFBFC);
  }

  static Color separator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFF1A3A6B).withValues(alpha: 0.08);
  }

  static Color subtleFill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF1A3A6B).withValues(alpha: 0.05);
  }

  static Color inkMuted(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52);
  }

  static const double surfaceRadius = 16;
  static const double pillRadius = 18;
  static const double navBarRadius = 22;
}
