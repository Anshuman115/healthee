/// `HRV · 14 days` — a fortnight drawn as **departure from the owner's normal**.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:248` — the
/// module header carrying the current reading on the right instead of a tag dot,
/// a 52 px chart, 7 px, and the research note under it.
///
/// Legacy draws this only when the sparkline has **more than two** points
/// (`_nums(spark['hrv_sleep_avg']).length > 2`), which is stricter than the two a
/// line needs: two nights is not a trend and a chart of it invites reading one as
/// one. `today_body.dart` keeps that gate.
///
/// ## The owner-directed departure, 2026-08-06
///
/// Legacy fills this chart to the floor of its box, which encodes absolute
/// RMSSD. Absolute RMSSD is the least useful thing about it: it is noisy,
/// strongly individual, and the note printed directly under this chart has
/// always said *"trends matter far more than any single night"*. Meanwhile the
/// owner reported that this chart and three others *"all look similar"* — and
/// they did, because all four were the same fill-to-the-floor area.
///
/// It now fills to the **baseline line** ([HDeviation]), so the ink is the one
/// quantity worth reading: how far this night sits from the owner's own normal,
/// and on which side. Legacy already had this concept in words on its recovery
/// ladder ("BALANCE +8 ↑"); this puts it in the chart.
///
/// ## Where the baseline comes from, and what happens when there is none
///
/// [baseline] is the server's 30-day median for `hrv_sleep_avg` and nothing
/// else — `TodayFacts._hrvBaseline` documents the two blocks that carry it and
/// why they are one definition rather than two. **It is null on the committed
/// contract snapshot**, because that payload's `recovery.signals` contains only
/// the sleep marker, and `hrv_sleep_avg` has no metric card on any payload.
///
/// A null baseline draws no line and no fill, and the foot says so. It is not
/// replaced by a median of the fourteen points on screen: that would be a second
/// definition of the owner's normal over a different window, which is the exact
/// failure `CLAUDE.md` names, and it would look completely convincing.
///
/// ## Where the baseline's caption went, 2026-08-06
///
/// It was painted inside the plot, and on the installed build
/// `YOUR 30-DAY NORMAL 53 MS` lay across the trace: neither the words nor the
/// line could be read. It is a [ChartReferenceCaption] under the chart now.
/// `chart_reference.dart` records the rule — a reference line may be drawn in
/// the plot, its label may not sit on the data.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/features/today/widgets/metric_note.dart';
import 'package:healthee/features/today/widgets/trailing_reading.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/h_deviation.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// A fortnight of overnight HRV against its baseline, with the note that reads it.
class HrvTrendCard extends StatelessWidget {
  /// [series] is oldest first and is never padded.
  const HrvTrendCard({
    required this.series,
    required this.reading,
    required this.baseline,
    required this.reveals,
    super.key,
  });

  /// The 14 nights.
  final List<double> series;

  /// Last night's value and its honesty state.
  final Reading<double> reading;

  /// The server's 30-day median, or null when it ships none.
  final double? baseline;

  /// Where "this chart has already animated" is remembered. The screen's.
  final RevealRegistry reveals;

  /// Legacy's `HArea(..., height: 52)`.
  static const double chartHeight = 52;

  @override
  Widget build(BuildContext context) {
    final tint = context.hues.hrv;
    final median = baseline;
    final references = <ChartReference>[
      if (median != null)
        ChartReference.personalBaseline(
          value: median,
          label: 'Your 30-day normal ${median.round()} ms',
        ),
    ];
    return InstrumentModule(
      label: 'HRV · 14 days',
      tag: tint,
      // `TrailingReading` draws a figure or a hole and CANNOT carry a caveat —
      // a 20 px header slot has no room for one. Without this line a caveated
      // HRV rendered as a bare number: the value shown, the tilt on it silently
      // dropped, which is the exact silence `Caveated` exists to prevent.
      caveats: reading.caveatsOrEmpty,
      minHeight: 0,
      trailing: TrailingReading(
        reading: reading,
        format: (value) => '${value.round()} ms',
        color: tint,
      ),
      children: [
        RevealOnce(
          id: 'today.hrv-trend',
          registry: reveals,
          builder: (context, t) => HDeviation(
            series,
            color: tint,
            progress: t,
            height: chartHeight,
            reference: references.isEmpty ? null : references.first,
          ),
        ),
        ChartReferenceCaption(references),
        if (median == null)
          const ModuleFoot('No 30-day baseline from the server yet'),
        const SizedBox(height: 7),
        MetricNote(hrvNote(reading.valueOrNull, median)),
      ],
    );
  }
}
