/// The two pieces under the biological-age hero's rule.
///
/// Split out of `bio_hero.dart` at the 400-line gate (Standards §1). They are
/// the two things the hero draws that are **not** the figure: the contributions
/// grid, and the line naming the model. Both are public because the hero is not
/// the only card that will carry a footer of terms — the age-waterfall screen
/// shows the same pair — and a second copy of either is a second opinion about
/// how a model names itself.
///
/// ```css
/// .bio-bottom       { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
/// .bio-bottom span  { font-size:10px; opacity:.85; }
/// .bio-bottom strong{ font-size:17px; font-weight:600; }
/// .model-label      { font-size:9px; margin-top:14px; opacity:.8; gap:5px; }
/// .model-label .icon{ width:11px; height:11px; }
/// ```
///
/// **Both take the hero's ink as a parameter, which is not a hole in the
/// no-`Color` rule.** The hero card has its own dark surface in both themes
/// (`bioBackground` / `bioInk` are tokens for exactly that reason), so nothing
/// inside it may reach for the page's ink — and these two are inside it. The
/// colour is the hero's, handed to its own parts, not a hue a call site chose.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One of the statistics under the hero's rule.
@immutable
class BioStat {
  /// Builds a statistic: a small [label] over a larger [value].
  const BioStat(this.label, this.value);

  /// `.bio-bottom span`.
  final String label;

  /// `.bio-bottom strong`.
  final String value;
}

/// `.bio-bottom` — the model's terms, side by side.
class BioStatsRow extends StatelessWidget {
  /// [ink] is the hero's own ink; see the library docstring.
  const BioStatsRow({required this.stats, required this.ink, super.key});

  /// `.bio-bottom { gap: 16px }`.
  static const double spacing = 16;

  /// `.bio-bottom span { opacity: .85 }`.
  static const double labelOpacity = 0.85;

  /// The terms, in the payload's order.
  final List<BioStat> stats;

  /// The hero's ink.
  final Color ink;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (var i = 0; i < stats.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: spacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                stats[i].label,
                style: TypeScale.bioStatLabel.copyWith(
                  color: ink.withValues(alpha: ink.a * labelOpacity),
                ),
              ),
              Text(
                stats[i].value,
                style: TypeScale.bioStat.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

/// `.model-label` — which model produced the figure, said quietly and always.
class BioModelLabel extends StatelessWidget {
  /// Builds the line.
  const BioModelLabel({
    required this.label,
    required this.ink,
    this.icon,
    super.key,
  });

  /// `.model-label .icon { width: 11px }`.
  static const double iconSize = 11;

  /// `.model-label { gap: 5px }`.
  static const double gap = 5;

  /// `.model-label { opacity: .8 }`.
  static const double opacity = 0.8;

  /// What produced the figure.
  final String label;

  /// Drawn before it.
  final IconData? icon;

  /// The hero's ink.
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final faded = ink.withValues(alpha: ink.a * opacity);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: iconSize, color: faded),
          const SizedBox(width: gap),
        ],
        Flexible(
          child: Text(
            label,
            style: TypeScale.modelLabel.copyWith(color: faded),
          ),
        ),
      ],
    );
  }
}
