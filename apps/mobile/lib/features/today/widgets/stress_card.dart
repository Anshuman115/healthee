/// `Stress · today` — the strap's `stress` signal, hour by hour, as columns.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:261` — the
/// `Builder` that picks between the intraday series and the daily trend, titles
/// itself accordingly, and puts the mean of whichever it picked in the header.
/// That selection rule, its threshold and the header mean are unchanged.
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
/// ## One owner-directed departure, and one rename UNDONE, 2026-08-06
///
/// The owner reported that this chart and three others *"all look similar"*.
/// They were all one 52 px area line. This one is now **hourly columns** — 24
/// discrete hours, which is what the series actually is, and a mark no other
/// chart on this screen's vitals run uses. That stands.
///
/// The title was also changed to **Arousal**, and that was wrong. Owner:
/// *"stress is named as AROUSAL."* `wearable_stress_validity` is SAFETY-CRITICAL
/// and its four directives govern **claims about the value** — never a mood,
/// never a verdict, never an alarm, only caveated trends against the owner's own
/// baseline. Not one of them is about what the card is called, and the
/// verbatim-legacy rule (`feedback_port_legacy_design_verbatim`) says keep
/// legacy's label. Renaming the metric was reading a directive as licence for a
/// design change it does not ask for — and it cost the owner the word his strap,
/// his old app and every other screen use for the same number.
///
/// ## The four directives, and where each one lands here
///
///   * **D1 — never a psychological/emotional/mental state.** The title is the
///     device's own word for the signal, which is a name and not a claim.
///     Nothing on this card names a feeling, and nothing bands the number into
///     one: no "calm", no "stressed", no "elevated", no verdict of any kind.
///     `test/features/vitals_stress_test.dart` enumerates this card's states and
///     asserts the absence in every one, and `test/mutations.sh` puts a banded
///     emotional label back to prove the test would catch it.
///   * **D2 — never infer mood or valence.** Same surface, same assertion:
///     "stressed" and "excited" are the same signal and this card says neither.
///   * **D3 — a high or low value is non-specific; never alarm.** The columns
///     are one colour (`allHighlighted`), so no hour is singled out, and the
///     card paints no `fav`/`unf`/`alert` token in any state. There is no
///     threshold on this chart because there is no defensible one to draw.
///   * **D4 — unvalidated on our hardware; caveated personal trends only.** The
///     ⓘ is wired to the `stress` explainer, which says so in as many words and
///     cites the note; `test/shared/metric_info_grounding_test.dart` holds that
///     link. That sentence is the caveat, and the ⓘ is its route.
///
/// ## The baseline this chart cannot draw
///
/// The other three vitals charts are read against a reference. This one has
/// none, and that is a finding rather than an omission: `stress` is **not a
/// `derived_daily` metric at all** in v2 (`analytics/metrics.py` drops it), so
/// the server computes no baseline for it, ships no `median_30d`, no `z`, and a
/// permanently empty `sparklines.stress`. The only honest options were to draw
/// no reference or to invent one from the hours on screen — and a baseline
/// derived from today's own 12 hours is not the owner's normal, it is today
/// compared with itself. So the card draws none.
///
/// The foot says what the chart **is** first, and names the absence second. It
/// used to read `THE STRAP CALLS THIS STRESS · NO PERSONAL BASELINE FOR IT` —
/// an apology in the loudest line on the card, and half of it was only there
/// because the title had been renamed away from the strap's word. The absence is
/// true and stays; it is no longer the headline.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/metric_hue.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Today's hourly stress if there is enough of it, else the fortnight's.
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

  /// The 14-day trend. **Empty on every live payload** — see the library
  /// docstring; the server has no daily `stress` metric to build it from.
  final List<double> daily;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// Legacy's threshold for preferring today over the fortnight — its
  /// `intra.length > 2`.
  static const int intradayMinimum = 3;

  /// Legacy's `HArea(..., height: 52)`, kept as the slot height so the card
  /// occupies the same space it always has.
  static const double chartHeight = 52;

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
      infoKey: 'stress',
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
          builder: (context, t) => SizedBox(
            height: chartHeight,
            // Every column in the metric's own hue. `HBars` defaults to
            // emphasising the last bar, and singling out the latest hour of a
            // signal the corpus calls non-specific (D3) is the beginning of a
            // verdict about it.
            child: HBars(
              series,
              color: tint,
              progress: t,
              height: chartHeight,
              allHighlighted: true,
            ),
          ),
        ),
        const ModuleFoot(
          "The strap's own hourly score · no server baseline behind it",
        ),
      ],
    );
  }
}
