/// The ONLY file in this app allowed to contain a colour literal.
///
/// Engineering Standards §3: "Design tokens only — colors/typography/spacing from
/// the theme system, no inline `Color(0xFF…)` in feature code." A rule like that
/// needs somewhere for the hex to live, and this is it. Everything else reaches
/// colour through [HealtheeColors] on the theme (`context.colors`), never here.
///
/// ## Which brand this is, and why that question was open
///
/// `docs/APP_DESIGN.md` §7.1 lists "brand accent — green vs indigo" as an open
/// decision gating the visual build. **Both options are retired.** Green was the
/// old app-side "warm editorial × instrument" system; indigo/iris was the landing
/// page's v3 "The Instrument". The landing has since moved to **v5 "The Ledger"**,
/// which `apps/landing/DESIGN.md` records as the binding design law and which the
/// owner picked ingredient by ingredient. Taking the app anywhere else would give
/// the product two brands and re-open a question that has been answered.
///
/// So these values are v5's, transcribed from `apps/landing/DESIGN.md` §3 — the
/// same hex, so a screenshot of the app and a screenshot of the page are the same
/// product. Two rules from that table carry over exactly:
///
///   * **One accent, a clay/terracotta.** It marks actions, links and the owner's
///     own data line. It is never "success" — this product has no green ring, and
///     `feedback_no_composite_score` plus APP_DESIGN §1's "honest colour" rule ban
///     traffic-light scoring outright. Score strips use a monochrome opacity ramp.
///   * **`warn` is a cool slate reserved for honesty moments** — the
///     insufficient-data chip, the refusal, the withheld card. "A held breath, not
///     an alarm; a feature colour, not an error colour." It is deliberately NOT
///     the colour of failure; [HealtheeColors.danger] is, and the two must not be
///     used for each other's job.
///
/// **Brand colours are identical in both themes.** Only the neutrals re-pick.
library;

import 'package:flutter/material.dart';

/// v5 "The Ledger" — light. Warm archival paper.
abstract final class LightPalette {
  /// Page background.
  static const Color canvas = Color(0xFFF4F2ED);

  /// Raised surfaces — cards, sheets.
  static const Color card = Color(0xFFFBFAF6);

  /// Recessed bands.
  static const Color sunk = Color(0xFFEBE8E0);

  /// Primary text.
  static const Color ink = Color(0xFF201C15);

  /// Secondary text.
  static const Color inkSoft = Color(0xFF5B544A);

  /// Tertiary text — labels, captions, units.
  static const Color inkFaint = Color(0xFF8A8274);

  /// Hairline dividers.
  static const Color line = Color(0xFFE0DCCF);

  /// Card frames — the ledger's crisp border.
  static const Color lineStrong = Color(0xFFCBC5B4);
}

/// v5 "The Ledger" — dark. Warm charcoal.
abstract final class DarkPalette {
  /// Page background.
  static const Color canvas = Color(0xFF16130E);

  /// Raised surfaces — cards, sheets.
  static const Color card = Color(0xFF201C16);

  /// Recessed bands.
  static const Color sunk = Color(0xFF100D09);

  /// Primary text.
  static const Color ink = Color(0xFFF2EFE7);

  /// Secondary text.
  static const Color inkSoft = Color(0xFFB1A99A);

  /// Tertiary text — labels, captions, units.
  static const Color inkFaint = Color(0xFF7B7264);

  /// Hairline dividers.
  static const Color line = Color(0xFF2F2A22);

  /// Card frames — the ledger's crisp border.
  static const Color lineStrong = Color(0xFF423B30);
}

/// The colours that do NOT change between themes (owner decision, DESIGN.md §3).
abstract final class BrandPalette {
  /// The one accent — clay/terracotta. Actions, links, the owner's data line.
  static const Color accent = Color(0xFFBD4A2A);

  /// The accent, one step softer. Used for text on the accent's own tint.
  static const Color accentSoft = Color(0xFFC2542F);

  /// Text and icons sitting ON the accent.
  static const Color accentInk = Color(0xFFFFFFFF);

  /// Honesty moments — withheld, excluded, refused, insufficient data.
  ///
  /// A cool slate. This is the colour of "we won't guess", and it must never be
  /// used to mean "something broke".
  static const Color warn = Color(0xFF4D6488);

  /// Genuine failure — a request that did not come back, a sync that died.
  ///
  /// Distinct from [warn] on purpose. Muted rather than a signal red: an error is
  /// information, and this app does not alarm people about their own bodies. It
  /// is derived from the accent's hue family so the palette stays one system.
  static const Color danger = Color(0xFF9B3412);
}
