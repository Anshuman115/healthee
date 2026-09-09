/// Which direction is BETTER for a metric — the one table that says so.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ui/
/// insights_screen.dart:19`'s `_trendMeta`, which carries a polarity beside each
/// label: `+1 = higher is better, -1 = lower is better, 0 = neutral`. The verdict
/// arithmetic is legacy's too — `improving = pol == 0 ? null : (delta * pol > 0)`
/// — and it is here rather than in a widget so it can be tested against pinned
/// numbers instead of pixels.
///
/// ## Why this is a separate table from `core/theme/metric_hues.dart`
///
/// They look alike and they are opposites. `InstrumentHues.tagFor` is an **identity**
/// — a colour that says *which* metric this is and never how the owner did, and
/// `apps/mobile/README.md` makes that structural: it takes an id and nothing else,
/// so a hue driven by today's reading is not something a caller can express.
/// This table is the other thing entirely: it is what licenses `fav`/`unf`, which
/// are the app's only two colours that make a claim about the owner's own normal.
/// Merging them would put a verdict inside the function whose whole guarantee is
/// that it cannot make one.
///
/// ## Unknown and neutral are different facts, and both render no colour
///
/// [TrendVerdict.none] is returned for three genuinely different situations — a
/// metric this table has never heard of, a metric it knows to be neutral, and a
/// window that did not move — and that is deliberate: they differ in what a
/// maintainer should do about them, not in what the owner should be told. There
/// is no honest colour for any of the three.
///
/// **The neutral case is the load-bearing one.** Calories are in this table at
/// polarity 0 on purpose: burning more is not better and burning less is not
/// worse, and colouring the row would teach the owner that every colour on the
/// screen is a judgement — after which the ones that really are stop meaning
/// anything. `test/shared/metric_polarity_test.dart` breaks that case on purpose.
library;

/// Which way a metric has to move for the owner to be better off.
enum MetricPolarity {
  /// Higher is better — HRV, sleep regularity.
  higherIsBetter,

  /// Lower is better — resting heart rate.
  lowerIsBetter,

  /// Known, and genuinely neither. Calories are the case this exists for.
  neutral,
}

/// What a change over a window means, if anything.
enum TrendVerdict {
  /// Moved the way this metric is better for moving.
  favourable,

  /// Moved the other way.
  unfavourable,

  /// No claim: unknown metric, neutral metric, or a window that did not move.
  none,
}

/// The polarity of [metric], or null when this table has never heard of it.
///
/// Null rather than [MetricPolarity.neutral], because "we do not know" and "we
/// know it is neither" are different facts and only one of them is a gap somebody
/// should close. Both produce [TrendVerdict.none].
MetricPolarity? polarityOf(String metric) => _polarity[metric];

/// The verdict on a change of [delta] in [metric]. Never guesses.
///
/// Legacy's `improving = pol == 0 ? null : (delta * pol > 0)`, with the unknown
/// metric folded into the same answer and a flat window added: a delta of exactly
/// zero is not an improvement in either direction, and calling it one would be the
/// app finding good news in noise.
TrendVerdict verdictFor(String metric, double delta) {
  if (delta == 0) {
    return TrendVerdict.none;
  }
  return switch (polarityOf(metric)) {
    MetricPolarity.higherIsBetter =>
      delta > 0 ? TrendVerdict.favourable : TrendVerdict.unfavourable,
    MetricPolarity.lowerIsBetter =>
      delta < 0 ? TrendVerdict.favourable : TrendVerdict.unfavourable,
    MetricPolarity.neutral || null => TrendVerdict.none,
  };
}

/// Legacy's six, with legacy's polarities. Keys are the server's canonical ids —
/// the same ones `sparklines` is keyed by, so a trend cannot be drawn for a
/// series this table cannot judge without the mismatch being visible here.
///
/// Adding a metric is adding a claim about which direction is better for it, so
/// it is a decision rather than a lookup: an id absent from here renders with no
/// verdict, which is the honest state and not a bug to be tidied away.
const Map<String, MetricPolarity> _polarity = <String, MetricPolarity>{
  'hrv_sleep_avg': MetricPolarity.higherIsBetter,
  'rhr_daily': MetricPolarity.lowerIsBetter,
  'sleep_regularity_index': MetricPolarity.higherIsBetter,
  'sleep_score': MetricPolarity.higherIsBetter,
  'sleep_health_score_4dim': MetricPolarity.higherIsBetter,
  'total_calories': MetricPolarity.neutral,
  // **A claim, and a graded one.** `steps_mortality` is Established and the
  // relationship is monotonic upward over the range a person walks — more is
  // better, with a plateau rather than a reversal. It is not `neutral` like
  // `total_calories`, which mixes basal and active energy and moves with body
  // mass as readily as with effort.
  'steps_total': MetricPolarity.higherIsBetter,
};

/// The metrics a trends surface offers, in the order legacy listed them.
///
/// Exported so the screen does not keep a second list: a trend the screen draws
/// for a metric this file cannot judge would be a colourless row nobody intended,
/// and a metric here that the screen never draws would be a claim with no reader.
const List<String> kTrendMetrics = <String>[
  'hrv_sleep_avg',
  'rhr_daily',
  'sleep_regularity_index',
  'sleep_score',
  'sleep_health_score_4dim',
  'total_calories',
  // Added 2026-09-09, the day the server started sending the slot. Legacy's
  // Activity screen had a `Steps 30d` trend row and the rebuild had nowhere to
  // put one, because `read/today_series.py` had no `steps_total` sparkline —
  // see that file's own comment. It does now, so the app's ONE trends surface
  // gains the metric rather than Activity growing a second one.
  'steps_total',
];
