/// The four durations and the one curve the whole app animates on.
///
/// **Ported verbatim** from `healthee-legacy/app/lib/ui/theme.dart`'s `HMotion`.
/// The curve is the design's signature `cubic-bezier(.2,.7,.3,1)` — a fast start
/// that settles slowly, which is what makes a chart's draw-on read as an
/// instrument sweeping rather than a UI sliding.
library;

import 'package:flutter/animation.dart';

/// Legacy's motion scale.
abstract final class HMotion {
  /// 200 ms — a press, a toggle, a colour change.
  static const Duration fast = Duration(milliseconds: 200);

  /// 450 ms — a card revealing.
  static const Duration base = Duration(milliseconds: 450);

  /// 950 ms — a chart drawing itself on.
  static const Duration slow = Duration(milliseconds: 950);

  /// 40 ms — the delay between one revealed card and the next.
  static const Duration stagger = Duration(milliseconds: 40);

  /// The design's signature ease, `cubic-bezier(.2,.7,.3,1)`.
  static const Curve curve = Cubic(0.2, 0.7, 0.3, 1);
}
