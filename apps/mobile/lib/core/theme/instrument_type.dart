/// Legacy's five type roles, wearing Inter.
///
/// **Ported from** `healthee-legacy/app/lib/ui/theme.dart`'s `HType`. Every size,
/// weight, height and tracking coefficient below is legacy's, unchanged. The ONE
/// thing that differs is the face, which is the one typographic difference the
/// owner sanctioned:
///
/// ```text
///   legacy                          here
///   ────────────────────────────    ──────────────────
///   Newsreader   (serif display)    Inter
///   Hanken Grotesk (UI sans)        Inter
///   Space Mono   (numerals, labels) Inter (tabular figures)
/// ```
///
/// Three faces became one, and one of the three was a **monospace**. That is not
/// a loss for the thing a mono face was doing here: `typography.dart` turns
/// `FontFeature.tabularFigures()` on for every style in the app, so a column of
/// numbers still holds its glyph advances. What is genuinely gone is Space Mono's
/// texture on labels, and Newsreader's serif on display text.
///
/// ## [serif] is not serif
///
/// It keeps legacy's name so a ported screen reads the same as the legacy screen
/// it came from, and it keeps legacy's metrics (23 px, weight 400, height 1.05,
/// −0.01 em tracking). It renders in Inter.
///
/// ## The italic is GONE, and that is a finding rather than a deferral
///
/// [serif] used to take an `italic` flag, legacy's greeting passed it, and two
/// cards set `FontStyle.italic` on a source line. **All three rendered upright.**
/// Flutter does not synthesise a slant for a bundled family, so what looked like
/// three deliberate emphases were three parameters doing nothing — the exact
/// shape of a dead control, and invisible because the text still rendered
/// perfectly.
///
/// An earlier revision of this file called that a vendoring job left for later.
/// Under Manrope it was not one: that family published no italic companion at
/// all, so there was nothing to vendor. **Under Inter it is a choice** — Inter
/// ships an italic and it is deliberately not bundled, because nothing in the
/// app sets one and a style nobody draws is weight in the APK that would start
/// arriving by accident the moment it existed.
/// `test/core/typography_test.dart` fails if the app starts asking for one.
///
/// Nothing moved on screen: the two source lines were already distinguished by
/// `ink3`, which is what was actually doing the work.
///
/// ## The weight that WAS missing has been vendored
///
/// [number] is legacy's `HType.num` and asks for **w700**. The pubspec vendored
/// 400/500/600, so Flutter substituted 600 and every instrument readout in the
/// app was a shade light — with no error, no warning, and nothing on screen to
/// see. `Inter-Bold.ttf` is vendored at `wght=700` alongside the other three,
/// and the typography test derives BOTH sides (the
/// weights `lib/` names, and the weights `pubspec.yaml` declares) and compares
/// them, so the next such gap fails a build instead of shipping.
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
    double height = 1.05,
  }) => _style(
    color: color,
    size: size,
    weight: weight,
    height: height,
    tracking: -0.01 * size,
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
  /// The 700 is real now — `Inter-Bold.ttf` is vendored. It was requested and
  /// silently served at 600 for the whole of the port; see the library
  /// docstring, and note that `weight` was never rewritten to `w600` to match
  /// the bundle, which is why vendoring the face fixed all 74 call sites at once.
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
  }) => TextStyle(
    fontFamily: healtheeFontFamily,
    fontFamilyFallback: healtheeFontFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: tracking,
    color: color,
    fontFeatures: _tabular,
  );
}
