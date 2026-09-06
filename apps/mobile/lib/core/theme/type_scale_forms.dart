/// **v02's type scale, second half: the forms, rows and prose.**
///
/// The same transcription as `type_scale.dart` — the prototype's CSS, to the
/// pixel — split out of it at the 400-line gate (Standards §1). The seam is the
/// one `dimensions.dart` used when it left `tokens.dart`: that file's one reason
/// to change is a **panel's** typography, and this one's is a **form's**. The
/// supporting screens are almost entirely list rows, switches, fields and
/// sentences, and none of those sizes appears on an instrument panel.
///
/// **Every style here is colourless**, for the reason `type_scale.dart` gives:
/// the colour arrives at the point of use, so a style cannot carry a hue that
/// disagrees with the container it is drawn in.
///
/// Sizes and tracking are the CSS's:
///
/// ```text
///   h1                30px  600  -1.2   styles.css h1        (welcome)
///   detail h1         23px  600  -0.8   styles.css .page-header.detail h1
///   h2                19px  700  -0.6   styles.css h2
///   h3                15px  400  -0.2   styles.css h3
///   body / small      14 / 12px         styles.css body, small
///   list row          13px 700 / 11px   styles.css .list-row strong / small
///   toggle row        12px 700 / 10px   screens.css .toggle-row strong / p
///   field             12px 600 · 16px · 10px   screens.css .field
///   button            13px 700          styles.css .button
///   text button       12px 700          styles.css .text-button
///   badge             10px 700          styles.css .badge
///   stat              11 · 27 · 11px    screens.css .stat-*
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

/// The form and list half of v02's scale. Colourless; see the library docstring.
abstract final class FormType {
  /// `h1` — the one 30 px title, on Welcome. Not `.page-header h1`, which
  /// `richer.css` pulls down to 27; Welcome's headline sits in `.coach-intro`
  /// and keeps the base size.
  static final TextStyle displayTitle = _style(
    30,
    FontWeight.w600,
    height: 1.2,
    tracking: -1.2,
  );

  /// `.page-header.detail h1` — a sub-screen's name, beside its back button.
  static final TextStyle detailTitle = _style(
    23,
    FontWeight.w600,
    height: 1.2,
    tracking: -0.8,
  );

  /// `h2` — a centred heading on the device and pairing screens, and the brand.
  static final TextStyle heading2 = _style(
    19,
    FontWeight.w700,
    height: 1.4,
    tracking: -0.6,
  );

  /// `h3` — a card's own heading.
  static final TextStyle heading3 = _style(
    15,
    FontWeight.w400,
    height: 1.5,
    tracking: -0.2,
  );

  /// `body` — the default. Rare on these screens; almost everything is smaller.
  static final TextStyle body = _style(14, FontWeight.w400);

  /// `small`, `.small` — the sentence under a heading.
  static final TextStyle small = _style(12, FontWeight.w400);

  /// `.list-row strong` — a settings row's name.
  static final TextStyle rowTitle = _style(13, FontWeight.w700, height: 1.4);

  /// `.list-row small` — what the row leads to. Wraps; see `list_row.dart`.
  static final TextStyle rowSubtitle = _style(11, FontWeight.w400, height: 1.5);

  /// `.toggle-row strong` — a switch's name.
  static final TextStyle toggleTitle = _style(12, FontWeight.w700, height: 1.4);

  /// `.toggle-row p` — what turning it on does.
  static final TextStyle toggleBody = _style(10, FontWeight.w400, height: 1.6);

  /// `.field` — a field's label.
  static final TextStyle fieldLabel = _style(12, FontWeight.w600, height: 1.4);

  /// `.field input` — what is typed into it. **16 px is deliberate**: iOS zooms
  /// the page on focus at anything smaller, and the prototype sets it for that
  /// reason.
  static final TextStyle fieldInput = _style(16, FontWeight.w400, height: 1.4);

  /// `.field small` — the note under a field.
  static final TextStyle fieldHint = _style(10, FontWeight.w400, height: 1.6);

  /// `.form-note` — the sentence under a whole form.
  static final TextStyle formNote = _style(10, FontWeight.w400, height: 1.7);

  /// `.button` — every filled and outlined button's label.
  static final TextStyle button = _style(13, FontWeight.w700, height: 1.2);

  /// `.text-button` — a link with an arrow.
  static final TextStyle linkButton = _style(12, FontWeight.w700, height: 1.2);

  /// `.badge` — a short stamp beside a value.
  static final TextStyle badge = _style(10, FontWeight.w700, height: 1.3);

  /// `.notice strong` — the headline of a banner.
  static final TextStyle noticeTitle = _style(12, FontWeight.w700, height: 1.4);

  /// `.notice p` — its sentence.
  static final TextStyle noticeBody = _style(11, FontWeight.w400, height: 1.8);

  /// `.stat-label` — the label over a statistic. 11 px here, not the panel's 10.
  static final TextStyle statLabel = _style(11, FontWeight.w400, height: 1.4);

  /// `.stat-number` — the statistic.
  static final TextStyle statNumber = _style(
    27,
    FontWeight.w600,
    height: 1.4,
    tracking: -1,
  );

  /// `.stat-number > span` — its unit.
  static final TextStyle statUnit = _style(11, FontWeight.w400, height: 1.4);

  /// `.timeline-item h3` — one step of the pairing journey.
  static final TextStyle timelineTitle = _style(
    13,
    FontWeight.w400,
    height: 1.5,
  );

  /// `.timeline-item p` — what that step does.
  static final TextStyle timelineBody = _style(11, FontWeight.w400, height: 1.6);

  /// `.timeline-item .node` — the number in the circle.
  static final TextStyle timelineNode = _style(11, FontWeight.w400, height: 1.2);

  /// `.theme-option` — one of Light · Dark · System.
  static final TextStyle themeOption = _style(12, FontWeight.w400, height: 1.3);

  /// `.sync-stages > div` — one stage of strap → phone → server.
  static final TextStyle syncStage = _style(10, FontWeight.w400, height: 1.4);

  /// `.coach-intro h2` — Welcome's and About's headline.
  static final TextStyle introTitle = _style(
    26,
    FontWeight.w700,
    height: 1.35,
    tracking: -1,
  );

  /// `.coach-intro p` — the paragraph under it.
  static final TextStyle introBody = _style(12, FontWeight.w400, height: 1.9);

  /// `.observation h3` — one row of the data-freshness list.
  static final TextStyle observationTitle = _style(
    17,
    FontWeight.w400,
    height: 1.5,
  );

  /// `.observation p` — how old that reading is.
  static final TextStyle observationBody = _style(
    12,
    FontWeight.w400,
    height: 1.9,
  );
}
