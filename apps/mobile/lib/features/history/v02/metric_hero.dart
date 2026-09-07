/// `.metric-hero` — the figure a metric's own screen opens on.
///
/// ```css
/// .metric-hero p            { font-size: 12px }
/// .metric-hero .hero-number { margin-top: 20px; font-size: 68px }
/// .hero-number              { line-height:1; font-weight:600;
///                             letter-spacing:-5px }
/// .hero-number .unit        { font-size:24px; letter-spacing:-1px;
///                             margin-left:3px; color:var(--muted) }
/// .section                  { margin-top: 24px }
/// ```
///
/// `screens-explore.js::H.screens.metric` draws, in order: the date line, the
/// number with its unit, and the metric's own sentence under it.
///
/// ## Not `HeroReading`
///
/// That widget is `.sleep-hero` — 64 px, `-4` tracking, an 8 px gap under the
/// number and a `.duration-unit` at 30. Every one of those five measurements
/// differs here, so reusing it would mean a flag argument per measurement to
/// render a different CSS rule. `stat_block.dart` records the same call for
/// `.stat` inside and outside a panel.
///
/// ## The number is a `Reading`, and a refusal is not a dash
///
/// A withheld figure does not reach this widget: `ReadingView` draws the
/// refusal instead, with the server's own reason. What [value] of `null` means
/// here is narrower and is the prototype's own case — the store holds no
/// observation for the day being viewed — and the caller's [context_] is what
/// says so. A dash with no sentence beside it would be this app inventing a
/// placeholder, which `stat_block.dart` refuses for the same reason.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// The date line, the figure, and the sentence under it.
class MetricHero extends StatelessWidget {
  /// [value] of null draws the em dash the prototype draws for an unmeasured
  /// day; [context_] must then say why.
  const MetricHero({
    required this.label,
    required this.value,
    this.unit,
    this.context_,
    super.key,
  });

  /// `.metric-hero .hero-number { margin-top: 20px }`.
  static const double numberGap = 20;

  /// `.section { margin-top: 24px }` — the copy under the figure.
  static const double copyGap = 24;

  /// `.hero-number .unit { margin-left: 3px }`.
  static const double unitGap = 3;

  /// `H.formatReading(null)` — the prototype's own em dash.
  static const String noReading = '—';

  /// The line above the figure — `Latest · 31 July`, or the day being viewed.
  final String label;

  /// The figure. Null draws [noReading].
  final String? value;

  /// Its unit. Dropped with the figure, so a dash never carries one.
  final String? unit;

  /// The sentence under the figure.
  final String? context_;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = TypeScale.small.copyWith(color: colors.ink2);
    final reading = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: small),
        const SizedBox(height: numberGap),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: reading ?? noReading),
              if (reading != null && unit != null && unit!.isNotEmpty) ...<
                InlineSpan
              >[
                // `margin-left: 3px`. A leading space would scale with the
                // 24 px unit rather than staying 3 px, so the gap is a box.
                const WidgetSpan(child: SizedBox(width: unitGap)),
                TextSpan(
                  text: unit,
                  style: TypeScale.metricHeroUnit.copyWith(color: colors.ink2),
                ),
              ],
            ],
          ),
          style: TypeScale.metricHeroNumber.copyWith(color: colors.ink),
          maxLines: 1,
        ),
        if (context_ case final String sentence) ...<Widget>[
          const SizedBox(height: copyGap),
          Text(sentence, style: small),
        ],
      ],
    );
  }
}
