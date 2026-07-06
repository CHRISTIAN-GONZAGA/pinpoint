import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinpoint/core/theme/app_colors.dart';
import 'package:pinpoint/core/theme/app_spacing.dart';
import 'package:pinpoint/core/theme/premium_tokens.dart';

/// Centralized Material 3 theme — refined, Apple-inspired clarity.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textTheme = _textTheme(brightness);
    final surfaceElevated = isLight ? Colors.white : const Color(0xFF1C1C1E);
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.08);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isLight ? AppColors.primary : AppColors.primaryLight,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: surfaceElevated,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? const Color(0xFFF2F2F7) : const Color(0xFF000000),
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        backgroundColor: isLight ? const Color(0xFFF2F2F7) : const Color(0xFF000000),
        foregroundColor: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        titleTextStyle: textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
          side: BorderSide(color: borderColor, width: 0.5),
        ),
        color: surfaceElevated,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: -0.1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: 14,
          ),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: TextStyle(
          color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: surfaceElevated.withValues(alpha: isLight ? 0.95 : 0.94),
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.1 : 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.45),
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 0.5),
      chipTheme: ChipThemeData(
        elevation: 0,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.pillRadius),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PremiumTokens.surfaceRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4),
      bodyMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
      bodySmall: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, height: 1.35),
      labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      labelMedium: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.2),
    );
  }
}
