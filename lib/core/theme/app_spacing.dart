/// Design tokens for spacing, radius, elevation, and animation.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double screenMargin = 24;
  static const double cardPadding = 20;
  static const double buttonPaddingH = 20;
  static const double buttonPaddingV = 16;
}

abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double full = 999;
}

abstract final class AppElevation {
  static const double low = 2;
  static const double medium = 6;
  static const double high = 12;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration splash = Duration(milliseconds: 2500);
}

abstract final class AppIconSizes {
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}
