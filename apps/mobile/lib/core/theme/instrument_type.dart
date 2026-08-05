/// Legacy's five type roles, wearing Manrope.
///
/// **Ported from** `healthee-legacy/app/lib/ui/theme.dart`'s `HType`. Every size,
/// weight, height and tracking coefficient below is legacy's, unchanged. The ONE
/// thing that differs is the face, which is the one typographic difference the
/// owner sanctioned:
///
/// ```text
///   legacy                          here
///   ────────────────────────────    ──────────────────
///   Newsreader   (serif display)    Manrope
///   Hanken Grotesk (UI sans)        Manrope
///   Space Mono   (numerals, labels) Manrope
/// ```
///
/// Three faces became one, and one of the three was a **monospace**. That is not
/// a loss for the thing a mono face was doing here: `typography.dart` turns
/// `FontFeature.tabularFigures()` on for every style in the app, so a column of
/// numbers still holds its glyph advances. What is genuinely gone is Space Mono's
/// texture on labels, and Newsreader's serif on display text.
///
/// ## Two ported behaviours that do not have a face to land on
///
///   * **[serif] is not serif.** It keeps legacy's name so a ported screen reads
///     the same as the legacy screen it came from, and it keeps legacy's metrics
///     (23 px, weight 400, height 1.05, −0.01 em tracking). It renders in Manrope.
///   * **[serif]'s `italic` currently renders upright.** `pubspec.yaml` vendors
///     three Manrope weights and no italic, and Flutter does not synthesise a
///     slant for a bundled family. The parameter is kept because legacy's
///     greeting asks for it and dropping it would silently lose the intent;
///     landing the italic means vendoring the face. Reported, not worked around.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/typography.dart';

/// Every digit at one advance width. The same list `typography.dart` applies to
/// the text theme; repeated here because these styles are built standalone.
const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

/// Legacy's type roles. One source of truth, exactly as `HType` was.
abstract final class HType {
  /// Display text — the greeting, a section head, a verdict word.
  ///
  /// Legacy's `HType.serif`: 23 px, weight 400, height 1.05, tracking −0.01 em.
  /// See the library docstring for why the name outlived the face.
  static TextStyle serif(
    Color color, {
    double size = 23,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
    double height = 1.05,
  }) => _style(
    color: color,
    size: size,
    weight: weight,
    height: height,
    tracking: -0.01 * size,
    italic: italic,
  );

  /// UI prose. Legacy's `HType.sans`: 14 px, weight 500, height 1.4.
  static TextStyle sans(
    Color color, {
    double size = 14,
    FontWeight weight = FontWeight.w500,
    double height = 1.4,
  }) => _style(
    color: color,
    size: size,
    weight: weight,
    height: height,
    tracking: 0,
  );

  /// The instrument readout. Legacy's `HType.num`: 27 px, weight 700, tabular,
  /// tracking −0.008 em.
  ///
  /// **Weight 700 is requested and 600 is what exists.** `pubspec.yaml` vendors
  /// 400/500/600 of Manrope; asking for 700 makes Flutter pick the nearest,
  /// which is 600. Legacy's numerals are therefore a shade lighter here. Named
  /// rather than quietly rewritten to `w600`, so that vendoring a 700 weight
  /// later restores legacy's figure without touching a single call site.
  static TextStyle number(
    Color color, {
    double size = 27,
    FontWeight weight = FontWeight.w700,
  }) => _style(
    color: color,
    size: size,
    weight: weight,
    height: 1,
    tracking: -0.008 * size,
  );

  /// The uppercase label under everything. Legacy's `HType.lbl`: 9 px, weight
  /// 400, tracking 0.12 em. [tracking] is in ems, as legacy passed it.
  static TextStyle label(
    Color color, {
    double size = 9,
    double tracking = 0.12,
  }) => _style(
    color: color,
    size: size,
    weight: FontWeight.w400,
    height: 1.3,
    tracking: tracking * size,
  );

  /// The wider eyebrow. Legacy's `HType.eyebrow`: 10 px, weight 400, and a flat
  /// **1.6 px** of tracking rather than an em multiple — legacy's own value.
  static TextStyle eyebrow(Color color) => _style(
    color: color,
    size: 10,
    weight: FontWeight.w400,
    height: 1.3,
    tracking: 1.6,
  );

  static TextStyle _style({
    required Color color,
    required double size,
    required FontWeight weight,
    required double height,
    required double tracking,
    bool italic = false,
  }) => TextStyle(
    fontFamily: healtheeFontFamily,
    fontFamilyFallback: healtheeFontFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking,
    color: color,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontFeatures: _tabular,
  );
}
