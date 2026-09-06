/// **v02's type scale, transcribed from the prototype's CSS.**
///
/// `typography.dart` builds the Material [TextTheme] the un-migrated screens are
/// written against; this file is the scale the v02 primitives use, and the two
/// coexist on purpose. Remapping `displayLarge` from 34 to v02's 88 would resize
/// every hero figure on every screen that has not been redesigned yet — a
/// restyle by side effect, and the phase boundary says no. When a screen moves to
/// v02 it moves onto these styles; when the last one has, `healtheeTextTheme`'s
/// role sizes go.
///
/// **Every style here is colourless.** The tone system supplies the colour at the
/// point of use (`context.family`, `context.colors.ink2`), so a style cannot
/// carry a hue that disagrees with the card it is in.
///
/// Sizes and tracking are the CSS's, to the pixel:
///
/// ```text
///   page h1        27px  -1px      richer.css .page-header h1
///   section h2     18px  -0.6px    richer.css .section-head h2 (size) + styles.css h2
///   panel title    13px  700       richer.css .panel-title
///   panel value    36px  600  -1.8 richer.css .panel-value
///   bio age        88px  600  -6   richer.css .bio-hero .age-value
///   tile value     24px       -1   richer.css .summary-tile strong
///   labels         8.5–11px        tile-meta · colour-key · panel-note · text-button
/// ```
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/typography.dart';

TextStyle _style(
  double size,
  FontWeight weight, {
  double height = 1.6,
  double tracking = 0,
}) => TextStyle(
  fontFamily: healtheeFontFamily,
  fontFamilyFallback: healtheeFontFallback,
  fontSize: size,
  fontWeight: weight,
  height: height,
  letterSpacing: tracking,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// v02's type scale. Colourless; see the library docstring.
abstract final class TypeScale {
  /// `.page-header h1` — the screen's name.
  static final TextStyle pageTitle = _style(
    27,
    FontWeight.w600,
    height: 1.2,
    tracking: -1,
  );

  /// `.page-header .date` — the date above it.
  static final TextStyle pageDate = _style(11, FontWeight.w500);

  /// `.section-head h2` — a section's name.
  static final TextStyle sectionTitle = _style(
    18,
    FontWeight.w700,
    height: 1.4,
    tracking: -0.6,
  );

  /// `.panel-title` — a panel's own title, beside its icon.
  static final TextStyle panelTitle = _style(13, FontWeight.w700, height: 1.35);

  /// `.panel-value` — the number a panel exists to show.
  static final TextStyle panelValue = _style(
    36,
    FontWeight.w600,
    height: 1.2,
    tracking: -1.8,
  );

  /// `.panel-value > small` — its unit.
  static final TextStyle panelUnit = _style(12, FontWeight.w400, height: 1.2);

  /// `.panel-note` — the sentence under a panel's chart.
  static final TextStyle panelNote = _style(11, FontWeight.w400, height: 1.7);

  /// `.panel .text-button` — a panel head's action.
  static final TextStyle textButton = _style(11, FontWeight.w700, height: 1.2);

  /// `.bio-hero .bio-eyebrow` — the hero's label row.
  static final TextStyle bioEyebrow = _style(12, FontWeight.w600, height: 1.4);

  /// `.bio-hero .age-value` — the one 88px figure in the product.
  static final TextStyle bioAge = _style(
    88,
    FontWeight.w600,
    height: 1,
    tracking: -6,
  );

  /// `.bio-hero .age-value small` — its unit.
  static final TextStyle bioAgeUnit = _style(13, FontWeight.w400, height: 1);

  /// `motion.css`'s override: the figure centred inside the halo, 84 not 88.
  static final TextStyle bioAgeCentred = _style(
    84,
    FontWeight.w600,
    height: 1,
    tracking: -5,
  );

  /// `motion.css`: `small { display:block; font-size:11px; letter-spacing:1px }`.
  static final TextStyle bioAgeUnitCentred = _style(
    11,
    FontWeight.w400,
    height: 1.4,
    tracking: 1,
  );

  /// `.bio-hero .age-context` — the sentence under the figure.
  static final TextStyle bioContext = _style(12, FontWeight.w400);

  /// `.bio-bottom strong` — a hero footer statistic.
  static final TextStyle bioStat = _style(17, FontWeight.w600, height: 1.3);

  /// `.bio-bottom span` — its label.
  static final TextStyle bioStatLabel = _style(10, FontWeight.w400, height: 1.4);

  /// `.bio-hero .model-label` — which instrument produced the figure.
  static final TextStyle modelLabel = _style(9, FontWeight.w400, height: 1.4);

  /// `.summary-tile .tile-title` — a tile's label, in its family colour.
  static final TextStyle tileTitle = _style(10, FontWeight.w400, height: 1.4);

  /// `.summary-tile strong` — a tile's number.
  static final TextStyle tileValue = _style(
    24,
    FontWeight.w700,
    height: 1.2,
    tracking: -1,
  );

  /// `.summary-tile .tile-meta` — the qualifier under it.
  static final TextStyle tileMeta = _style(8.5, FontWeight.w400, height: 1.4);

  /// `.colour-key` — a legend entry.
  static final TextStyle colourKey = _style(10, FontWeight.w400, height: 1.4);

  /// `.context-bridge p` — the connective sentence between two panels.
  static final TextStyle bridge = _style(11, FontWeight.w400, height: 1.8);

  /// `.panel-summary p` — the right-hand qualifier beside a panel's number.
  static final TextStyle panelContext = _style(11, FontWeight.w400, height: 1.5);

  /// `.twin-panels .panel-title` — a half-width panel's name.
  static final TextStyle panelTitleCompact = _style(
    11,
    FontWeight.w700,
    height: 1.35,
  );

  /// `.twin-panels .panel-value`. The tracking scales with the size: -1.8 at 36
  /// is -1.4 at 28, which keeps the glyphs at the same optical density.
  static final TextStyle panelValueCompact = _style(
    28,
    FontWeight.w600,
    height: 1.2,
    tracking: -1.4,
  );

  /// `.twin-panels .panel-value > small`.
  static final TextStyle panelUnitCompact = _style(
    10,
    FontWeight.w400,
    height: 1.2,
  );

  /// `.twin-panels .panel-note`.
  static final TextStyle panelNoteCompact = _style(
    10,
    FontWeight.w400,
    height: 1.7,
  );

  /// `.panel .stat-label` — the label over a statistic in a `.three` row.
  static final TextStyle statLabel = _style(10, FontWeight.w400, height: 1.4);

  /// `.panel .three .stat-number`.
  static final TextStyle statValue = _style(
    22,
    FontWeight.w600,
    height: 1.4,
    tracking: -1,
  );

  /// `.stat-number > span` — its unit.
  static final TextStyle statUnit = _style(11, FontWeight.w400, height: 1.4);

  /// `.chapter-heading h2` — a chapter's name.
  static final TextStyle chapterTitle = _style(
    20,
    FontWeight.w700,
    height: 1.4,
    tracking: -0.6,
  );

  /// `.chapter-nav button` — one jump target.
  static final TextStyle chapterNav = _style(10, FontWeight.w400, height: 1.2);

  /// `.factor-row` — a model component's name and its score.
  static final TextStyle factorRow = _style(11, FontWeight.w400, height: 1.4);

  /// `.dimension-cell > span` — an independent reading's name.
  static final TextStyle dimensionLabel = _style(
    11,
    FontWeight.w400,
    height: 1.4,
  );

  /// `.dimension-cell strong` — the reading.
  static final TextStyle dimensionValue = _style(
    22,
    FontWeight.w600,
    height: 1.3,
    tracking: -0.7,
  );

  /// `.dimension-cell small` — the reference under it.
  static final TextStyle dimensionNote = _style(9, FontWeight.w400, height: 1.4);

  /// `.device-strip` — the strap row under the title.
  static final TextStyle deviceStrip = _style(10, FontWeight.w400, height: 1.4);

  /// `.relationship-card h3` — an entry point's name.
  static final TextStyle entryTitle = _style(15, FontWeight.w700, height: 1.35);

  /// `.relationship-card p` — what it leads to.
  static final TextStyle entryBody = _style(11, FontWeight.w400, height: 1.6);

  /// `.data-footer` — the closing line.
  static final TextStyle footer = _style(10, FontWeight.w400, height: 2);

  /// `.data-footer span` — its second line.
  static final TextStyle footerFine = _style(9, FontWeight.w400, height: 2);

  /// `.date-caret` — the chevron beside the date the reader is on.
  static final TextStyle dateCaret = _style(13, FontWeight.w400, height: 1);

  /// `.calendar-heading strong` — the month a calendar is showing.
  static final TextStyle calendarMonth = _style(16, FontWeight.w700, height: 1.3);

  /// `.date-calendar button` — one day in the grid.
  static final TextStyle calendarDay = _style(13, FontWeight.w400, height: 1.2);

  /// `.date-calendar button[aria-current]` — the day being shown.
  static final TextStyle calendarDayCurrent = _style(
    13,
    FontWeight.w700,
    height: 1.2,
  );

  /// `.page-header.detail h1` — a pushed screen's name, smaller than a tab's.
  static final TextStyle detailTitle = _style(
    23,
    FontWeight.w600,
    height: 1.2,
    tracking: -0.8,
  );

  /// `.small` — the prototype's one step down from body copy.
  static final TextStyle small = _style(12, FontWeight.w400);

  /// `.tiny-label`, `.list-row small`, `.timeline-item p`, `.stat-label`.
  static final TextStyle tinyLabel = _style(11, FontWeight.w400);

  /// `.badge` — `font-size:10px; font-weight:700`.
  static final TextStyle badge = _style(10, FontWeight.w700);

  /// `.notice strong`.
  static final TextStyle noticeTitle = _style(12, FontWeight.w700);

  /// `.notice p`, `.focus-card p`, `.challenge-card p` — all `11px/1.8`.
  static final TextStyle noticeBody = _style(11, FontWeight.w400, height: 1.8);

  /// `.focus-card .focus-title`.
  static final TextStyle focusEyebrow = _style(10, FontWeight.w700);

  /// `.focus-card h3` — the base `h3` at the focus card's own size.
  static final TextStyle focusTitle = _style(
    14,
    FontWeight.w700,
    height: 1.5,
    tracking: -0.2,
  );

  /// `.sleep-hero .hero-number`.
  static final TextStyle heroNumber = _style(
    64,
    FontWeight.w600,
    height: 1,
    tracking: -4,
  );

  /// `.hero-number .duration-unit`.
  static final TextStyle heroUnit = _style(
    30,
    FontWeight.w400,
    height: 1,
    tracking: -1,
  );

  /// `.list-row strong`, `.timeline-item h3`, `.journal-strip h3`,
  /// `.check-action strong` — the base `h3` at 13.
  static final TextStyle rowTitle = _style(
    13,
    FontWeight.w700,
    height: 1.5,
    tracking: -0.2,
  );

  /// `.challenge-card h3` — the base `h3` at 17.
  static final TextStyle challengeTitle = _style(
    17,
    FontWeight.w700,
    height: 1.5,
    tracking: -0.2,
  );

  /// `.stat-number` — the statistic inside a `.card`, NOT the `.panel .three`
  /// override [statValue] transcribes. Two sizes because the prototype has two.
  static final TextStyle cardStatValue = _style(
    27,
    FontWeight.w600,
    height: 1.4,
    tracking: -1,
  );

  /// `.stat-number > span` — its unit.
  static final TextStyle cardStatUnit = _style(
    11,
    FontWeight.w400,
    height: 1.4,
  );

  /// `.button`.
  static final TextStyle buttonLabel = _style(13, FontWeight.w700);

  /// `.text-button` — the page-level link, not [textButton]'s in-panel 11px.
  static final TextStyle textLink = _style(12, FontWeight.w700);

  /// `.coach-intro h2`.
  static final TextStyle coachIntroTitle = _style(
    26,
    FontWeight.w700,
    height: 1.35,
    tracking: -1,
  );

  /// `.coach-intro p` and `.coach-message` — both `12px/1.9`.
  static final TextStyle coachBody = _style(12, FontWeight.w400, height: 1.9);

  /// `.form-note`, `.journal-strip p`.
  static final TextStyle formNote = _style(10, FontWeight.w400);

  /// `.field input` — 16px, which is also what keeps iOS from zooming a form.
  static final TextStyle inputText = _style(16, FontWeight.w400);
}
