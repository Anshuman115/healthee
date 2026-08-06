/// The card corner, and it is not a rounded rectangle.
///
/// **Ported from** `healthee-legacy/app/lib/ui/theme.dart`'s `hSquircle`. Legacy
/// draws every module, sheet and badge with a **continuous superellipse** corner
/// at `smoothness 0.6` — Apple's continuous corner, near enough — rather than a
/// circular arc. It is the single most-repeated shape in the app, and swapping it
/// for `RoundedRectangleBorder` changes the look of every card on every screen.
/// So the dependency (`smooth_corner`) travels with the design.
library;

import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// Legacy's `smoothness: 0.6`. Not a taste setting — it is the value the whole
/// design was drawn against.
const double kSquircleSmoothness = 0.6;

/// A continuous-corner rectangle at [radius], optionally with a hairline [side].
///
/// Verbatim from legacy: same smoothness, same parameter shape, same default of
/// no border.
ShapeBorder hSquircle(double radius, {BorderSide side = BorderSide.none}) =>
    SmoothRectangleBorder(
      smoothness: kSquircleSmoothness,
      borderRadius: BorderRadius.circular(radius),
      side: side,
    );
