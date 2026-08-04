/// Assembles the two [ThemeData]s. Both are authored; neither is derived.
///
/// A dark theme generated from a light one by inverting lightness is how a
/// palette gets muddy warm-greys and unreadable hairlines. v5's neutrals were
/// picked separately for each mode (`apps/landing/DESIGN.md` §3: "only the
/// neutrals re-pick for dark"), so both are built here from their own token set.
///
/// Nothing outside this file constructs a [ThemeData], and nothing outside
/// `palette.dart` names a colour value.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/typography.dart';

/// The app's light and dark themes.
abstract final class AppTheme {
  /// v5 "The Ledger" — light. The default (`apps/landing/DESIGN.md` §3).
  static ThemeData get light => _build(const HealtheeColors.light(), Brightness.light);

  /// v5 "The Ledger" — dark.
  static ThemeData get dark => _build(const HealtheeColors.dark(), Brightness.dark);

  static ThemeData _build(HealtheeColors colors, Brightness brightness) {
    final text = healtheeTextTheme(ink: colors.ink, inkSoft: colors.inkSoft);
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      extensions: <ThemeExtension<Object?>>[colors],
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      dividerColor: colors.line,
      fontFamily: healtheeFontFamily,
      fontFamilyFallback: healtheeFontFallback,
      textTheme: text,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.accentInk,
        secondary: colors.accentSoft,
        onSecondary: colors.accentInk,
        // Material's `error` is a genuine failure, so it takes `danger` — NOT the
        // honesty hue. A withheld number is not an error and must never inherit
        // an error colour by accident (see HealtheeColors.withheld).
        error: colors.danger,
        onError: colors.accentInk,
        surface: colors.card,
        onSurface: colors.ink,
        outline: colors.lineStrong,
        outlineVariant: colors.line,
      ),
      dividerTheme: DividerThemeData(
        color: colors.line,
        thickness: hairline,
        space: hairline,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0, // depth is the border, not a float (DESIGN.md §3)
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.lineStrong, width: hairline),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.accentInk,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          textStyle: text.labelLarge,
          side: BorderSide(color: colors.lineStrong, width: hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentSoft,
          textStyle: text.labelLarge,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.sunk,
      ),
    );
  }
}
