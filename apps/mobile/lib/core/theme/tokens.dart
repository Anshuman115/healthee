/// Semantic design tokens, reachable from any widget as `context.colors`.
///
/// Feature code names a ROLE (`colors.inkFaint`, `colors.withheld`) and never a
/// value. That is what makes both themes real: a widget written against roles is
/// correct in dark mode by construction, and one written against hex is a bug
/// nobody sees until they toggle.
///
/// This is a `ThemeExtension` rather than a set of top-level constants precisely
/// so it varies with the theme — Flutter's own `ColorScheme` does not have room
/// for tokens like "the colour of a withheld number", and squeezing them into
/// `tertiaryContainer` would be a naming lie.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/palette.dart';

/// Spacing scale. One rhythm, so gaps compose instead of accumulating.
abstract final class Insets {
  /// 4 — hairline gaps, chip padding.
  static const double xs = 4;

  /// 8 — between a label and its value.
  static const double sm = 8;

  /// 12 — inside a dense row.
  static const double md = 12;

  /// 16 — the default card padding and page gutter.
  static const double lg = 16;

  /// 24 — between cards.
  static const double xl = 24;

  /// 32 — between sections.
  static const double xxl = 32;
}

/// Corner radii — v5 is near-squared; depth comes from borders, not roundness.
abstract final class Radii {
  /// 6 — cards and sheets.
  static const double card = 6;

  /// 4 — chips and stamps.
  static const double chip = 4;

  /// 5 — buttons.
  static const double button = 5;
}

/// The one border width the ledger uses. Named because it is a decision.
const double hairline = 1;

/// Semantic colour roles for the whole app.
@immutable
class HealtheeColors extends ThemeExtension<HealtheeColors> {
  /// Builds a token set. Prefer [HealtheeColors.light] / [HealtheeColors.dark].
  const HealtheeColors({
    required this.canvas,
    required this.card,
    required this.sunk,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.withheld,
    required this.danger,
  });

  /// The light token set — v5 "The Ledger" on warm archival paper.
  const HealtheeColors.light()
    : canvas = LightPalette.canvas,
      card = LightPalette.card,
      sunk = LightPalette.sunk,
      ink = LightPalette.ink,
      inkSoft = LightPalette.inkSoft,
      inkFaint = LightPalette.inkFaint,
      line = LightPalette.line,
      lineStrong = LightPalette.lineStrong,
      accent = BrandPalette.accent,
      accentSoft = BrandPalette.accentSoft,
      accentInk = BrandPalette.accentInk,
      withheld = BrandPalette.warn,
      danger = BrandPalette.danger;

  /// The dark token set — the same brand hex on warm charcoal.
  const HealtheeColors.dark()
    : canvas = DarkPalette.canvas,
      card = DarkPalette.card,
      sunk = DarkPalette.sunk,
      ink = DarkPalette.ink,
      inkSoft = DarkPalette.inkSoft,
      inkFaint = DarkPalette.inkFaint,
      line = DarkPalette.line,
      lineStrong = DarkPalette.lineStrong,
      accent = BrandPalette.accent,
      accentSoft = BrandPalette.accentSoft,
      accentInk = BrandPalette.accentInk,
      withheld = BrandPalette.warn,
      danger = BrandPalette.danger;

  /// Page background.
  final Color canvas;

  /// Raised surfaces — cards, sheets.
  final Color card;

  /// Recessed bands.
  final Color sunk;

  /// Primary text.
  final Color ink;

  /// Secondary text — supporting prose.
  final Color inkSoft;

  /// Tertiary text — labels, units, captions.
  final Color inkFaint;

  /// Hairline dividers between rows.
  final Color line;

  /// Card frames.
  final Color lineStrong;

  /// The one accent. Actions, links, the owner's own data line.
  final Color accent;

  /// The accent, one step softer — for accent-coloured text.
  final Color accentSoft;

  /// Text and icons on top of [accent].
  final Color accentInk;

  /// The honesty hue: withheld, excluded, refused, insufficient data.
  ///
  /// Named for the state and not the colour ("warn" on the landing page) because
  /// a widget author reaching for it should be reaching for *the honesty state*.
  /// If a name suggests "warning", someone will eventually use it for an error,
  /// and the product's most careful moment will start reading as a fault.
  final Color withheld;

  /// Genuine failure — a request that never came back.
  final Color danger;

  @override
  HealtheeColors copyWith({
    Color? canvas,
    Color? card,
    Color? sunk,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? line,
    Color? lineStrong,
    Color? accent,
    Color? accentSoft,
    Color? accentInk,
    Color? withheld,
    Color? danger,
  }) {
    return HealtheeColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      sunk: sunk ?? this.sunk,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentInk: accentInk ?? this.accentInk,
      withheld: withheld ?? this.withheld,
      danger: danger ?? this.danger,
    );
  }

  @override
  HealtheeColors lerp(ThemeExtension<HealtheeColors>? other, double t) {
    if (other is! HealtheeColors) {
      return this;
    }
    return HealtheeColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      sunk: Color.lerp(sunk, other.sunk, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      withheld: Color.lerp(withheld, other.withheld, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Reaches the token set from a widget: `context.colors.inkFaint`.
extension HealtheeColorsOf on BuildContext {
  /// The active theme's semantic colours.
  ///
  /// Throws if the theme was built without the extension, which is the right
  /// behaviour — a silent fallback palette would let a screen render in colours
  /// nobody chose, and look almost right.
  HealtheeColors get colors => Theme.of(this).extension<HealtheeColors>()!;
}
