/// [HMeter] — the mini bar beside a sub-score in the legacy readiness card.
///
/// **Ported from** `design_reference/project/hh/ui.jsx`'s `ProgressBar`: a fully
/// rounded track, a fully rounded fill, default height 4 px in the readiness
/// rows. Legacy animated the width with a 1 s CSS transition kicked off by a
/// timeout; here the width is `fraction * progress` and the progress comes from
/// `RevealOnce`, for the reason `chart_primitives.dart` sets out.
///
/// ## A null value draws no bar, and that is the whole reason this widget exists
///
/// [fraction] is nullable. A recovery factor whose signal was missing has no
/// sub-score, and a zero-width bar is visually identical to a score of zero —
/// one says "we never measured this", the other says "we measured it and it was
/// as bad as it gets". So a null draws the track alone, and the row beside it
/// says "no signal" in words. `RecoveryCard` had this branch inline; it moved
/// here on its second use, which is Standards §1.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A rounded track with a rounded fill, revealed by [progress].
class HMeter extends StatelessWidget {
  /// [fraction] is 0–1, or null when the signal behind it is missing.
  const HMeter({
    required this.fraction,
    required this.color,
    required this.progress,
    this.height = 4,
    super.key,
  });

  /// How full the bar is, 0–1. Null draws the empty track and no fill.
  final double? fraction;

  /// The fill's colour. An identity tag, not a judgement colour.
  final Color color;

  /// How much of the fill has grown, 0–1.
  final double progress;

  /// The bar's thickness. 4 is legacy's readiness row.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = fraction;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.line2),
            if (filled != null)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: filled.clamp(0.0, 1.0) * progress.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }
}
