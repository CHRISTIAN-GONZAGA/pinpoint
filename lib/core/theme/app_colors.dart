import 'package:flutter/material.dart';

/// Route-signboard palette. Widgets should read these tokens, not raw hex.
abstract final class AppColors {
  // Light
  static const Color stage = Color(0xFFECEDE5);
  static const Color paper = Color(0xFFFBFBF7);
  static const Color sunken = Color(0xFFE1E2D8);
  static const Color ink = Color(0xFF141B26);
  static const Color inkSecondary = Color(0xFF4A5565);
  static const Color hairline = Color(0xFFCCCEC3);
  static const Color edge = Color(0xFF141B26);

  // Dark — night rides
  static const Color stageDark = Color(0xFF0F141C);
  static const Color paperDark = Color(0xFF171E29);
  static const Color sunkenDark = Color(0xFF212A38);
  static const Color inkDark = Color(0xFFF1EFE6);
  static const Color inkSecondaryDark = Color(0xFFA3ADBB);
  static const Color hairlineDark = Color(0xFF2B3544);
  static const Color edgeDark = Color(0xFF3A4658);

  static const Color primary = Color(0xFF1B46C9);
  static const Color primaryLight = Color(0xFF3A60EC);
  static const Color primaryText = Color(0xFF8CA5FF);
  static const Color signal = Color(0xFFFFC400);
  static const Color danger = Color(0xFFD63A28);
  static const Color dangerText = Color(0xFFC22E1C);
  static const Color dangerDark = Color(0xFFE0533F);
  static const Color dangerTextDark = Color(0xFFFF7B66);
  static const Color accent = Color(0xFF15805A);
  static const Color accentDark = Color(0xFF2FB583);
  static const Color secondary = Color(0xFF0E7FA8);
  static const Color warning = signal;

  static const Color backgroundLight = stage;
  static const Color surfaceLight = paper;
  static const Color backgroundDark = stageDark;
  static const Color surfaceDark = paperDark;
  static const Color textPrimaryLight = ink;
  static const Color textSecondaryLight = inkSecondary;
  static const Color textPrimaryDark = inkDark;
  static const Color textSecondaryDark = inkSecondaryDark;

  static const Color catAttraction = Color(0xFF1E8A5A);
  static const Color catFood = Color(0xFFC9650F);
  static const Color catHotel = Color(0xFF7A55D6);
  static const Color catMall = Color(0xFF0E7FA8);
  static const Color catHospital = Color(0xFFD63A28);

  static const List<Color> routePalette = [
    Color(0xFF1B46C9),
    Color(0xFFD63A28),
    Color(0xFF15805A),
    Color(0xFFFFC400),
  ];

  static Color routeColorAt(int index) => routePalette[index.abs() % routePalette.length];

  static bool routeNeedsDarkInk(Color color) => color.toARGB32() == signal.toARGB32();

  static Color stageOf(Brightness brightness) =>
      brightness == Brightness.dark ? stageDark : stage;

  static Color paperOf(Brightness brightness) =>
      brightness == Brightness.dark ? paperDark : paper;

  static Color sunkenOf(Brightness brightness) =>
      brightness == Brightness.dark ? sunkenDark : sunken;

  static Color inkOf(Brightness brightness) =>
      brightness == Brightness.dark ? inkDark : ink;

  static Color inkSecondaryOf(Brightness brightness) =>
      brightness == Brightness.dark ? inkSecondaryDark : inkSecondary;

  static Color hairlineOf(Brightness brightness) =>
      brightness == Brightness.dark ? hairlineDark : hairline;

  static Color edgeOf(Brightness brightness) =>
      brightness == Brightness.dark ? edgeDark : edge;

  static Color primaryFillOf(Brightness brightness) =>
      brightness == Brightness.dark ? primaryLight : primary;

  static Color dangerOf(Brightness brightness) =>
      brightness == Brightness.dark ? dangerDark : danger;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [accent, accentDark],
  );
  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [danger, dangerDark],
  );
  static const LinearGradient nightGradient = LinearGradient(
    colors: [stageDark, paperDark],
  );
}
