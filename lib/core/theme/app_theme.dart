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
    final surfaceElevated = AppColors.paperOf(brightness);
    final borderColor = AppColors.hairlineOf(brightness);
    final edge = AppColors.edgeOf(brightness);
    final primaryFill = AppColors.primaryFillOf(brightness);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primaryFill,
      onPrimary: Colors.white,
      secondary: AppColors.signal,
      onSecondary: AppColors.ink,
      tertiary: isLight ? AppColors.accent : AppColors.accentDark,
      onTertiary: Colors.white,
      error: AppColors.dangerOf(brightness),
      onError: Colors.white,
      surface: surfaceElevated,
      onSurface: AppColors.inkOf(brightness),
      onSurfaceVariant: AppColors.inkSecondaryOf(brightness),
      outline: borderColor,
      outlineVariant: borderColor,
      shadow: Colors.transparent,
      scrim: Colors.black54,
      inverseSurface: AppColors.inkOf(brightness),
      onInverseSurface: AppColors.paperOf(brightness),
      inversePrimary: isLight ? AppColors.primaryText : AppColors.primary,
      surfaceContainerHighest: AppColors.sunkenOf(brightness),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.stageOf(brightness),
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        backgroundColor: AppColors.stageOf(brightness),
        foregroundColor: AppColors.inkOf(brightness),
        titleTextStyle: textTheme.titleLarge?.copyWith(letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: edge, width: 2),
        ),
        color: surfaceElevated,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(48, 52),
          backgroundColor: primaryFill,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sunkenOf(brightness),
          disabledForegroundColor: AppColors.inkSecondaryOf(brightness),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
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
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: AppColors.inkOf(brightness),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonPaddingH,
            vertical: 14,
          ),
          side: BorderSide(color: edge, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: edge, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: edge, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryFill, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dangerOf(brightness), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: surfaceElevated,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.inkOf(brightness)
                : AppColors.inkSecondaryOf(brightness),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 24 : 22,
            color: selected
                ? AppColors.inkOf(brightness)
                : AppColors.inkSecondaryOf(brightness),
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
    final ink = AppColors.inkOf(brightness);
    final muted = AppColors.inkSecondaryOf(brightness);
    final body = GoogleFonts.atkinsonHyperlegibleTextTheme(base);

    TextStyle display(double size) => GoogleFonts.archivoNarrow(
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 0.95,
          letterSpacing: -0.6,
          color: ink,
        );

    return body.copyWith(
      displayLarge: display(44),
      displayMedium: display(36),
      headlineLarge: display(34),
      headlineMedium: display(28),
      headlineSmall: display(23),
      titleLarge: GoogleFonts.atkinsonHyperlegible(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: ink,
      ),
      titleMedium: GoogleFonts.atkinsonHyperlegible(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleSmall: GoogleFonts.atkinsonHyperlegible(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: GoogleFonts.atkinsonHyperlegible(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: ink,
      ),
      bodyMedium: GoogleFonts.atkinsonHyperlegible(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: ink,
      ),
      bodySmall: GoogleFonts.atkinsonHyperlegible(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: muted,
      ),
      labelLarge: GoogleFonts.atkinsonHyperlegible(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      labelMedium: GoogleFonts.atkinsonHyperlegible(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
      labelSmall: GoogleFonts.atkinsonHyperlegible(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: muted,
      ),
    );
  }
}
