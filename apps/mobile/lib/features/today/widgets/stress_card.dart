/// `Stress · today` — or `Stress · 14 days` when today has not filled in yet.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:261` — the
/// `Builder` that picks between the intraday series and the daily trend, titles
/// itself accordingly, and puts the mean of whichever it picked in the header.
///
/// The rule is legacy's and worth stating because it is the honest one: the
/// intraday series wins only when it has **more than two** hours in it, so a
/// screen opened at 07:00 shows the fortnight rather than a "today" built from
/// one hour. The title changes with the data, so the two are never confused.
///
/// The hours are the SERVER's aggregation (`today_stress_series`), not the
/// phone's. The phone holds the raw samples and could average them itself —
/// which is exactly why it must not: an hourly mean computed two ways is two
/// definitions of one number, and the server's is the canonical one.
///
/// Legacy draws the whole module in `cCal` — the calories hue, not the stress
/// hue. That is a legacy inconsistency (`metric_hue.dart` records it) and it is
/// ported: `hueFor(hues, 'stress')` resolves to the same colour.
///
/// ## What this replaced
///
/// The previous revision drew hourly **bars** with an axis, which was this
/// rebuild's design. Legacy draws one area line at 52 px with the mean in the
/// header and no axis, and legacy is the specification.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/metric_hue.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Today's stress if there is enough of it, else the fortnight's.
class StressCard extends StatelessWidget {
  /// [intraday] is today's hours; [daily] is the 14-day trend.
  const StressCard({
    required this.intraday,
    required this.daily,
    required this.reveals,
    super.key,
  });

  /// Today's hourly averages.
  final List<double> intraday;

  /// The 14-day sparkline.
  final List<double> daily;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's threshold for preferring today over the fortnight — its
  /// `intra.length > 2`.
  static const int intradayMinimum = 3;

  /// Whether either series is worth drawing at all. Legacy's outer condition:
  /// more than two intraday points **or** at least two daily ones.
  static bool hasSomethingToDraw(List<double> intraday, List<double> daily) =>
      intraday.length >= intradayMinimum || daily.length >= 2;

  @override
  Widget build(BuildContext context) {
    final tint = hueFor(context.hues, TodayMetricIds.stress);
    final useIntraday = intraday.length >= intradayMinimum;
    final series = useIntraday ? intraday : daily;
    final average = series.isEmpty
        ? null
        : (series.reduce((a, b) => a + b) / series.length).round();
    return InstrumentModule(
      label: useIntraday ? 'Stress · today' : 'Stress · 14 days',
      tag: tint,
      minHeight: 0,
      trailing: average == null
          ? null
          : Text(
              '$average avg',
              style: HType.number(tint, size: 13, weight: FontWeight.w700),
            ),
      children: [
        RevealOnce(
          // One id for both shapes: it is the same card about the same metric,
          // and a chart that re-animated because the day filled in would be
          // replaying on data rather than on a reveal.
          id: 'today.stress',
          registry: reveals,
          builder: (context, t) =>
              HArea(series, color: tint, progress: t, height: 52),
        ),
      ],
    );
  }
}
