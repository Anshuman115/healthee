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
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/last_known.dart';

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

/// What stands in the figure's place when the server refused the number.
///
/// Two states, and the difference between them is the whole design:
///
///   * **nothing held** — a dash at the figure's own size. The hero keeps its
///     ground, radius, padding, eyebrow and model label; only the number is
///     gone. A refused hero is still a hero.
///   * **a value held from an earlier day** — the owner asked for this: *"it
///     should show the old one instead of completely not showing"*. It is drawn
///     [staleOpacity] faded, under a **dashed rule**, over a date line in full
///     ink. That is three separate signals that it is not today's, and they are
///     deliberately not all captions: this repo's most-repeated defect is a
///     stale value read as current, so the figure has to LOOK different before a
///     word is read. The dash is the same vocabulary `ValueHole` and
///     `WithheldPanel` use for absence, applied to a number that is present but
///     out of date.
///
/// The date is never truncated and never faded. It is not a footnote — it is
/// what makes drawing the figure at all legitimate, so it renders at the hero's
/// own ink, wraps rather than ellipsizes, and has no `maxLines`.
class BioWithheldFigure extends StatelessWidget {
  /// [value] is preformatted; null draws the dash. [asOf] is `YYYY-MM-DD`.
  const BioWithheldFigure({
    required this.ink,
    this.value,
    this.asOf,
    super.key,
  })  : assert(
          (value == null) == (asOf == null),
          'A stale figure without its date is the stale-as-current bug this '
          'widget exists to make unrepresentable; a date with no figure is a '
          'caption about nothing. Pass both, or neither.',
        );

  /// Identifies the faded figure, so a test can measure what was painted.
  static const Key staleFigureKey = ValueKey<String>('bio-hero.stale-figure');

  /// Identifies the dash drawn when nothing is held.
  static const Key holeKey = ValueKey<String>('bio-hero.no-value');

  /// Identifies the date line, so a test can prove it is on screen and whole.
  static const Key dateKey = ValueKey<String>('bio-hero.as-of');

  /// How faded a value that is no longer current is drawn.
  static const double staleOpacity = 0.55;

  /// How faint the dash is when there is nothing to show at all.
  static const double holeOpacity = 0.4;

  /// The em dash that stands where the number would be.
  static const String noValue = '—';

  /// What the date line says before the date.
  static const String asOfPrefix = 'Last known · as of ';

  /// The gap above the dashed rule, and below it.
  static const double ruleGap = 10;

  /// The dashed rule's own thickness, dash and gap.
  static const double dash = 5;

  /// The gap between one dash and the next.
  static const double dashGap = 4;

  /// The hero's ink. See the library docstring for why this is a parameter.
  final Color ink;

  /// The last value this phone held, already formatted. Null draws the dash.
  final String? value;

  /// The calendar day [value] belonged to, `YYYY-MM-DD`.
  final String? asOf;

  @override
  Widget build(BuildContext context) {
    final held = value;
    final day = asOf;
    if (held == null || day == null) {
      return Text(
        noValue,
        key: holeKey,
        style: TypeScale.bioAge.copyWith(
          color: ink.withValues(alpha: ink.a * holeOpacity),
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Opacity(
          opacity: staleOpacity,
          child: Text(
            held,
            key: staleFigureKey,
            style: TypeScale.bioAge.copyWith(color: ink),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
        const SizedBox(height: ruleGap),
        SizedBox(
          height: hairline,
          child: CustomPaint(
            painter: _DashedRule(colour: ink),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: ruleGap),
        Text(
          '$asOfPrefix${plainDay(day)}',
          key: dateKey,
          style: TypeScale.bioContext.copyWith(color: ink),
        ),
      ],
    );
  }
}

/// The broken rule under a value that is no longer current.
class _DashedRule extends CustomPainter {
  const _DashedRule({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    var at = 0.0;
    while (at < size.width) {
      final end = at + BioWithheldFigure.dash;
      canvas.drawLine(
        Offset(at, y),
        Offset(end > size.width ? size.width : end, y),
        paint,
      );
      at = end + BioWithheldFigure.dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedRule oldDelegate) => oldDelegate.colour != colour;
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
