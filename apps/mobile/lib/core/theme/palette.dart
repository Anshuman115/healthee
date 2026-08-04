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

/// The three **identity tags** — the one deliberate extension to the design above.
///
/// ## Why the palette grew at all
///
/// The legacy Today screen (`design_reference/project/hh/screen_today.jsx`) is a
/// grid of instrument modules, each carrying a coloured dot and a chart tinted to
/// match: sleep purple, heart red-orange, HRV green, steps amber, energy orange,
/// respiratory teal, SpO₂ blue, stress rose. That per-metric colour IS the legacy
/// design language, and the owner asked for that language. This palette had no
/// per-metric family, and `tokens.dart` says why: *"in this app a colour is a
/// claim."*
///
/// Two things forced a decision rather than a straight refusal:
///
///   * **A hypnogram needs more than one hue.** `stage_colors.dart` used to draw
///     all four sleep stages as one accent at 100%/55%/30% alpha. Three tints of
///     indigo in a chart 30 px tall is unreadable, which makes the picture of the
///     night a decoration rather than a reading.
///   * **A grid of seven modules tinted one colour is not the legacy screen.**
///     The tint ties a card's dot to its sparkline; drop it and the grid loses the
///     thing that makes it scannable.
///
/// ## What makes these NOT judgement colours
///
/// A verdict must be able to change — "worse than your normal" is a claim that is
/// true some days and false others. **A tag never changes.** It is a constant of
/// the metric, fixed at compile time in `metric_hues.dart`, and there is no API
/// anywhere that derives a tag from a value. A colour that cannot vary cannot
/// encode a verdict, and a reader who watches the screen for two days sees the
/// dots stay put while `fav`/`unf`/`alert` move.
///
/// That structural argument is backed by a chromatic one: the three tags are
/// **hue-disjoint from every judgement colour**. Measured in OKLCH, the closest
/// approach in either theme is 48° (heart vs [LightPalette.alert]), against 55°
/// and 119° between the tags themselves. Nothing here is within reach of the
/// product's green, amber or red, so a tag cannot be mistaken for one at a glance.
///
/// ## Why three, and why one of them is the accent
///
/// Legacy had eight hues. Eight cannot be had honestly here: excluding the
/// neighbourhoods of `fav` (161°), `unf` (69°) and `alert` (29°) leaves about
/// 170° of usable wheel, and eight hues inside it are 21° apart — indistinguishable
/// at the 6 px a dot actually occupies. Three at ~60° spacing are unmistakable.
///
/// [rest] is [LightPalette.accent] itself rather than a fourth literal. Legacy did
/// the same — its `--green` was the brand colour AND the HRV hue AND the readiness
/// hue — and it means this extension adds **two** colour literals per theme, which
/// is the smallest change that buys the language back.
///
/// All three sit at one lightness (OKLCH L 0.510 / 0.510 / 0.541 here) precisely
/// so none reads as ranked above another, and each clears 4.4:1 against both the
/// card and the page.
abstract final class LightTagPalette {
  /// Sleep, HRV, readiness — what the body does at rest. The accent itself.
  static const Color rest = LightPalette.accent;

  /// Heart rate, resting heart rate, stress. OKLCH L 0.510 · C 0.170 · H 340°.
  static const Color heart = Color(0xFFA13384);

  /// Steps, energy, breathing, blood oxygen. OKLCH L 0.541 · C 0.096 · H 221°.
  static const Color body = Color(0xFF0E7B96);
}

/// The identity tags, dark. Authored against `#141419`, not lightened from light.
///
/// See [LightTagPalette] for the whole argument. The lightnesses here are the
/// dark theme's own (OKLCH L 0.685 / 0.684 / 0.737), and the hue gaps hold: 48°
/// to [DarkPalette.alert] at the closest, 56° between the tags.
abstract final class DarkTagPalette {
  /// Sleep, HRV, readiness. The dark accent itself.
  static const Color rest = DarkPalette.accent;

  /// Heart rate, resting heart rate, stress. OKLCH L 0.684 · C 0.151 · H 340°.
  static const Color heart = Color(0xFFD571B7);

  /// Steps, energy, breathing, blood oxygen. OKLCH L 0.737 · C 0.103 · H 216°.
  static const Color body = Color(0xFF4FBAD3);
}
