/// `Active minutes · MVPA` — the week against 150, with its daily bars.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:1280` —
/// `_MvpaModule`. Anatomy unchanged: the week's minutes as a 40 px figure over
/// the target with the percentage on the right, a 6 px bar, a 40 px bar strip of
/// the daily minutes with every bar highlighted, then three stat columns.
///
/// ```text
///   ACTIVE MINUTES · MVPA                         this week
///   160  / 150 min                                     107%
///   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬
///   ▮ ▮▮ ▮ ▮▮▮ ▮
///   MODERATE   VIGOROUS   TODAY
///      120         20       32
/// ```
///
/// `allHighlighted` on the bar strip is legacy's: these are days of a week, not
/// a trend with a "latest" to pick out.
///
/// Legacy falls back to a two-bar `[0, 0]` strip when there are fewer than two
/// days (`bars.length >= 2 ? bars : [0, 0]`). That draws two empty bars where no
/// day was measured, so the strip is simply not drawn here when the payload has
/// nothing in it — `today_facts.dart` carries the argument.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/features/today/widgets/stat_columns.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/instrument/h_progress_bar.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Moderate-to-vigorous minutes, this week and today.
class MvpaCard extends StatelessWidget {
  /// [mvpa] is the whole `mvpa` block.
  const MvpaCard({required this.mvpa, required this.reveals, super.key});

  /// The week's minutes, its target, and the daily breakdown.
  final Mvpa mvpa;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's `SizedBox(height: 40, child: HBars(..., height: 40))`.
  static const double barsHeight = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final week = mvpa.weekMin;
    final target = mvpa.weekTarget;
    final percent = target == 0 ? 0 : (week / target * 100).round();
    final bars = <double>[
      for (final day in mvpa.daily) day.mvpaMin.toDouble(),
    ];
    return InstrumentModule(
      label: 'Active minutes · MVPA',
      tag: colors.accent,
      minHeight: 0,
      trailing: Text(
        'this week',
        style: HType.number(colors.ink3, size: 10, weight: FontWeight.w400),
      ),
      children: [
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$week',
              style: HType.number(
                colors.ink,
                size: 40,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ $target min',
              style: HType.number(
                colors.ink3,
                size: 13,
                weight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: HType.number(
                colors.accent,
                size: 16,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RevealOnce(
          id: 'today.mvpa-week',
          registry: reveals,
          builder: (context, t) => HProgressBar(
            value: week.toDouble(),
            max: target.toDouble(),
            progress: t,
            height: 6,
            color: colors.accent,
            semanticLabel: '$week of $target active minutes this week',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: barsHeight,
          child: RevealOnce(
            id: 'today.mvpa-daily',
            registry: reveals,
            builder: (context, t) => HBars(
              bars,
              color: colors.accent,
              progress: t,
              height: barsHeight,
              allHighlighted: true,
              unit: 'min',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            StatColumn(label: 'MODERATE', value: '${mvpa.weekModerateMin}'),
            StatColumn(label: 'VIGOROUS', value: '${mvpa.weekVigorousMin}'),
            StatColumn(label: 'TODAY', value: '${mvpa.todayMin}'),
          ],
        ),
      ],
    );
  }
}
