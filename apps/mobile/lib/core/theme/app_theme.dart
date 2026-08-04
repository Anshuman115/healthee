/// Assembles the two [ThemeData]s. Both are authored; neither is derived.
///
/// A dark theme generated from a light one by inverting lightness is how a
/// palette gets muddy greys and unreadable hairlines. `docs/APP_DESIGN_BRIEF.md`
/// §2 is explicit — "Both are authored above — do not derive one by inverting the
/// other" — so both are built here from their own token set.
///
/// Nothing outside this file constructs a [ThemeData], and nothing outside
/// `palette.dart` names a colour value.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/typography.dart';

/// The app's light and dark themes.
abstract final class AppTheme {
  /// The approved design, light. The default (brief §2).
  static ThemeData get light => _build(const HealtheeColors.light(), Brightness.light);

  /// The approved design, dark.
  static ThemeData get dark => _build(const HealtheeColors.dark(), Brightness.dark);

  static ThemeData _build(HealtheeColors colors, Brightness brightness) {
    final text = healtheeTextTheme(ink: colors.ink, ink2: colors.ink2, ink3: colors.ink3);
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      extensions: <ThemeExtension<Object?>>[colors],
      scaffoldBackgroundColor: colors.bg,
      canvasColor: colors.bg,
      dividerColor: colors.line,
      fontFamily: healtheeFontFamily,
      fontFamilyFallback: healtheeFontFallback,
      textTheme: text,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        // `secondary` is the stronger accent, not the soft wash. accentSoft is a
        // translucent FILL and would render Material's secondary-coloured text
        // as a ghost of the background.
        secondary: colors.accent2,
        onSecondary: colors.onAccent,
        // Material's own widgets (form validation, `TextField` errors) need a
        // red, and `alert` is the only one in the product. App-authored failure
        // states do NOT use it — see the note in tokens.dart. Reserving alert for
        // illness is a rule about OUR cards; it cannot stop Material having an
        // error colour, and leaving this at the M3 default would introduce a
        // second red nobody chose.
        error: colors.alert,
        onError: colors.onAccent,
        surface: colors.surface,
        onSurface: colors.ink,
        surfaceContainerLow: colors.surface2,
        outline: colors.line,
        outlineVariant: colors.line2,
      ),
      dividerTheme: DividerThemeData(
        color: colors.line2,
        thickness: hairline,
        space: hairline,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        // "almost no shadow — depth from spacing and contrast" (brief §2).
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.line, width: hairline),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),
      appBarTheme: AppBarTheme(
        // `chrome`, not `bg` — the app frame is its own surface in this design,
        // and in light mode it is white against a grey page.
        backgroundColor: colors.chrome,
        foregroundColor: colors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.chrome,
        selectedItemColor: colors.accent,
        unselectedItemColor: colors.ink3,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          textStyle: text.labelLarge,
          side: BorderSide(color: colors.line, width: hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // `accent`, not `accentSoft` — the wash is 9% opaque and a text button
          // wearing it was invisible. (Latent bug from the previous palette,
          // where `accentSoft` happened to be a solid colour.)
          foregroundColor: colors.accent,
          textStyle: text.labelLarge,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surface2,
      ),
    );
  }
}
