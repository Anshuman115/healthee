/// An arrow and a signed number — "and here is which way it moved".
///
/// **Ported verbatim** from `healthee-legacy/app/lib/ui/ui.dart`'s `HDeltaBadge`:
/// the arrow is one point larger than the figure, a zero draws no arrow at all,
/// and the colour is
///
/// ```dart
/// value == 0 ? c.ink3 : (isGood ? c.green : c.cHeart)
/// ```
///
/// ## This widget is where legacy's colour collision is most visible
///
/// Green for better, red-orange for worse — **the same two hues that are HRV and
/// heart rate everywhere else in the app**. `insights_screen.dart:171` is the
/// canonical line (`improving ? c.green : c.cHeart`). Identity and judgement
/// share hues here **by decision**, and this is not a bug to be repaired by
/// introducing a separate verdict palette. See `palette.dart`.
///
/// ## [good] is "is THIS change favourable", not "is up favourable"
///
/// Worth stating because the other reading is the intuitive one and it inverts
/// the badge. Legacy's line is `final isGood = good ?? up;` — the caller passes a
/// verdict about the delta being shown, and the default only holds for metrics
/// where rising happens to be the good direction.
///
/// So `HDeltaBadge(-4, good: false)` is a fall that is bad news, and draws red;
/// a resting heart rate that fell would be `HDeltaBadge(-4, good: true)`. The
/// polarity table that decides which is which lives beside the metric
/// (`shared/format/metric_polarity.dart`), never inside a badge — a widget that
/// resolved its own verdict from a metric id would be one refactor away from
/// colouring a card by how the owner did.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:solar_icons/solar_icons.dart';

/// A signed delta with a direction arrow.
class HDeltaBadge extends StatelessWidget {
  /// [value] is the signed change; [good] says whether up is the better way.
  const HDeltaBadge(
    this.value, {
    this.suffix = '',
    this.good,
    this.size = 11,
    super.key,
  });

  /// The change, already in display units. Zero draws no arrow.
  final num value;

  /// A unit appended to the figure — `'ms'`, `'%'`.
  final String suffix;

  /// Whether THIS change is the favourable one. Null falls back to legacy's
  /// `good ?? up`, which is wrong for a falling resting heart rate — pass it.
  final bool? good;

  /// The figure's size. The arrow is drawn one point larger.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final up = value > 0;
    final favourable = good ?? up;
    final colour = value == 0 ? colors.ink3 : (favourable ? colors.fav : colors.alert);
    final text = '${value > 0 ? '+' : ''}$value$suffix';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != 0)
          Icon(
            up ? SolarIconsOutline.arrowUp : SolarIconsOutline.arrowDown,
            size: size + 1,
            color: colour,
          ),
        Text(
          text,
          style: HType.number(colour, size: size),
          // Colour is the only thing saying which way this reads, and a screen
          // reader cannot see it. "Unchanged" is its own answer, not a verdict.
          semanticsLabel: value == 0
              ? '$text, unchanged'
              : '$text, ${favourable ? 'better' : 'worse'}',
        ),
      ],
    );
  }
}
