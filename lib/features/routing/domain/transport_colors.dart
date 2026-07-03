import 'package:flutter/material.dart';
import 'package:pinpoint/core/utilities/color_utils.dart';

/// Standard map colors for each transport mode.
abstract final class TransportColors {
  static const Color walk = Color(0xFF64748B);
  static const Color tricycle = Color(0xFFF59E0B);
  static const Color taxi = Color(0xFFEAB308);
  static const Color transfer = Color(0xFF8338EC);

  static Color jeepney(String? routeCode) {
    if (routeCode == null) return const Color(0xFF1A3A6B);
    return colorFromHex(_jeepneyHex(routeCode));
  }

  static String _jeepneyHex(String code) => switch (code) {
        'R1' => '#E63946',
        'R2' => '#F4A261',
        'R3' => '#2A9D8F',
        'R4' => '#457B9D',
        'R5' => '#8338EC',
        'R6' => '#FB5607',
        'R7' => '#06D6A0',
        _ => '#1A3A6B',
      };
}
