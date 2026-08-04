/// The ONLY file in this app allowed to contain a colour literal.
///
/// Engineering Standards §3: "Design tokens only — colors/typography/spacing from
/// the theme system, no inline `Color(0xFF…)` in feature code." A rule like that
/// needs somewhere for the hex to live, and this is it. Everything else reaches
/// colour through [HealtheeColors] on the theme (`context.colors`), never here.
///
/// ## Which design this is
///
/// The approved app design (`Healthee.html`, owner decision 2026-08-04:
/// *"the colors and fonts all we will keep from new"*), transcribed verbatim into
/// `docs/APP_DESIGN_BRIEF.md` §2 and again here. Direction: **modern instrument** —
/// a well-made measuring device, not a lifestyle magazine.
///
/// **The app and the landing page deliberately diverge.** `apps/landing` is v5
/// "The Ledger" — warm paper, clay accent. This is indigo on near-white and
/// near-black. That is the owner's choice, not drift, and it settles
/// `docs/APP_DESIGN.md` §7.1: neither option that question offered (app green,
/// landing v3 iris) survived.
///
/// ## What the previous revision of this file got wrong
///
/// It argued, carefully and at length, for v5's clay — because v5 was the only
/// authored token set in the repo at the time. Two of its structural premises are
/// now dead, and are named here so nobody reinstates them:
///
///   * **"Brand colours are identical in both themes."** True of v5, false here.
///     [LightPalette.accent] and [DarkPalette.accent] are a PAIR, and the second
///     is not the first re-lightened — `#5145e5` on white and `#8f87ff` on
///     near-black were each chosen against their own background. The old
///     `BrandPalette`, whose entire premise was theme-invariant brand colour, is
///     gone rather than half-kept.
///   * **A dedicated honesty HUE.** The old palette gave a withheld value a cool
///     slate. This design spends no colour on it at all — see [LightPalette.hole].
///
/// ## The semantic rule that governs everything below
///
/// Brief §2: *"Only `fav`/`unf` carry judgement; `alert` is reserved for the
/// illness flag alone. Everything else is greyscale + accent. Never colour a card
/// to decorate it."*
///
/// Three colours here are allowed to say something about the owner's body —
/// [LightPalette.fav], [LightPalette.unf], [LightPalette.alert] — plus their
/// tints. Every other value is structure. Reaching for one of the three to make a
/// card look interesting is the rule broken, and it is not a rule about taste:
/// in this app a colour is a claim.
library;

import 'package:flutter/material.dart';

/// The approved design — light. The default theme (brief §2).
abstract final class LightPalette {
  /// Page background, behind every surface.
  static const Color bg = Color(0xFFF4F4F6);

  /// Cards and sheets.
  static const Color surface = Color(0xFFFFFFFF);

  /// A recessed or secondary surface inside a card.
  static const Color surface2 = Color(0xFFFAFAFB);

  /// App frame — top bar and tab bar. The same value as [surface] in this theme
  /// but a separate role: the frame is not a card, and dark mode may part them.
  static const Color chrome = Color(0xFFFFFFFF);

  /// Primary text and hero figures.
  static const Color ink = Color(0xFF121217);

  /// Secondary text — the sentence under a number.
  static const Color ink2 = Color(0xFF56565F);

  /// Tertiary text — labels, units, captions, and a signal sitting at baseline.
  static const Color ink3 = Color(0xFF6D6D7C);

  /// Hairline dividers and card borders.
  static const Color line = Color.fromRGBO(18, 18, 23, 0.10);

  /// The lighter hairline — rows inside a list, the rule under the app bar.
  static const Color line2 = Color.fromRGBO(18, 18, 23, 0.06);

  /// The one accent. Actions, links, the owner's own data line.
  static const Color accent = Color(0xFF5145E5);

  /// The accent under pressure — pressed, hovered, the stronger of the pair.
  static const Color accent2 = Color(0xFF3F34C9);

  /// A wash of the accent, as a fill behind accent content.
  static const Color accentSoft = Color.fromRGBO(81, 69, 229, 0.09);

  /// Text and icons sitting ON [accent]. White here — measured at 6.30:1.
  ///
  /// Not a new colour: it is [surface]. See [DarkPalette.onAccent] for why this
  /// role exists at all rather than being a hardcoded white in both themes.
  static const Color onAccent = surface;

  /// Favourable — this reading sits better than the owner's own normal.
  static const Color fav = Color(0xFF1A7F57);

  /// [fav] as a fill.
  static const Color favSoft = Color.fromRGBO(26, 127, 87, 0.10);

  /// Unfavourable — this reading sits worse than the owner's own normal.
  static const Color unf = Color(0xFFA4680B);

  /// [unf] as a fill.
  static const Color unfSoft = Color.fromRGBO(164, 104, 11, 0.10);

  /// The illness flag, and nothing else.
  static const Color alert = Color(0xFFB8352A);

  /// [alert] as a fill.
  static const Color alertSoft = Color.fromRGBO(184, 53, 42, 0.08);

  /// The number-shaped absence — a very low-alpha fill, not a text colour.
  static const Color hole = Color.fromRGBO(18, 18, 23, 0.045);
}

/// The approved design — dark. Authored, never derived by inverting light.
abstract final class DarkPalette {
  /// Page background, behind every surface.
  static const Color bg = Color(0xFF0A0A0E);

  /// Cards and sheets.
  static const Color surface = Color(0xFF141419);

  /// A recessed or secondary surface inside a card.
  static const Color surface2 = Color(0xFF1A1A21);

  /// App frame — top bar and tab bar.
  static const Color chrome = Color(0xFF141419);

  /// Primary text and hero figures.
  static const Color ink = Color(0xFFF3F3F6);

  /// Secondary text — the sentence under a number.
  static const Color ink2 = Color(0xFFA2A2B0);

  /// Tertiary text — labels, units, captions, and a signal sitting at baseline.
  static const Color ink3 = Color(0xFF8D8D99);

  /// Hairline dividers and card borders.
  static const Color line = Color.fromRGBO(255, 255, 255, 0.10);

  /// The lighter hairline — rows inside a list, the rule under the app bar.
  static const Color line2 = Color.fromRGBO(255, 255, 255, 0.055);

  /// The one accent. Lighter than its light-mode partner, not a tint of it.
  static const Color accent = Color(0xFF8F87FF);

  /// The accent under pressure — pressed, hovered, the stronger of the pair.
  static const Color accent2 = Color(0xFFA9A2FF);

  /// A wash of the accent, as a fill behind accent content.
  static const Color accentSoft = Color.fromRGBO(143, 135, 255, 0.14);

  /// Text and icons sitting ON [accent] — the page background, not white.
  ///
  /// ## The one place this implementation departs from `Healthee.html`
  ///
  /// The design hardcodes `color:#fff` on an accent-filled surface (the coach's
  /// own message bubble). Against the light theme's `#5145e5` that measures
  /// **6.30:1** and is right. Against this theme's `#8f87ff` it measures
  /// **2.97:1** — below WCAG AA for normal text (4.5:1) and below even the 3:1
  /// large-text floor. The same white is doing two different jobs because the
  /// prototype had one literal where the token set has a pair.
  ///
  /// [bg] on that accent measures **6.66:1**. So the departure is a role
  /// assignment, not a new colour — both values were already approved, and the
  /// alternative is shipping text nobody with ordinary eyesight reads comfortably
  /// in the theme this product defaults to at night. Flagged for the owner.
  static const Color onAccent = bg;

  /// Favourable — this reading sits better than the owner's own normal.
  static const Color fav = Color(0xFF4FC691);

  /// [fav] as a fill.
  static const Color favSoft = Color.fromRGBO(79, 198, 145, 0.14);

  /// Unfavourable — this reading sits worse than the owner's own normal.
  static const Color unf = Color(0xFFDFA550);

  /// [unf] as a fill.
  static const Color unfSoft = Color.fromRGBO(223, 165, 80, 0.14);

  /// The illness flag, and nothing else.
  static const Color alert = Color(0xFFFF7466);

  /// [alert] as a fill.
  static const Color alertSoft = Color.fromRGBO(255, 116, 102, 0.12);

  /// The number-shaped absence — a very low-alpha fill, not a text colour.
  static const Color hole = Color.fromRGBO(255, 255, 255, 0.05);
}
