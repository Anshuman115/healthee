/// **v02's type scale, third seam: the date control and its calendar.**
///
/// Split out of `type_scale.dart` at the 400-line gate (Standards section 1),
/// the same way `type_scale_forms.dart` was and for the same reason: that file's
/// one reason to change is a **panel's** typography, and these four sizes belong
/// to the date affordance on Today — the caret, the month heading, and a day
/// cell in its two states. Two files use them, both in `features/today/v02/`.
///
/// **Colourless**, like the rest of the scale: the colour arrives at the point
/// of use, so a style cannot carry a hue that disagrees with its container.
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

/// The date control's scale. Colourless; see the library docstring.
abstract final class DateType {
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
}
