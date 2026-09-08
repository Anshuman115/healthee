/// Everything legacy's `_Content.build` works out before it draws anything.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:113–216` — the
/// `mval` / `mitem` / `mz` / `mmed` lookups, the fallback chains behind each
/// figure, and the six tile inputs assembled from them. It is a value object
/// rather than a pile of locals so that `today_sections.dart` can stay a list of
/// widgets in an order, which is all a screen should be (Standards §3).
///
/// ## The one place this is NOT legacy, and it is the whole point of the rebuild
///
/// Legacy's charts take a **fabricated fallback series**:
///
/// ```dart
/// // today_screen.dart:183
/// HArea(_nums(spark['rhr_daily'], fallback: [rhr ?? 56, rhr ?? 56]), …)
/// ```
///
/// With no sparkline it draws a flat line at today's value; with no value either
/// it draws a flat line at **56 bpm** — a number belonging to nobody. The same
/// pattern invents 45 ms of HRV, 300 kcal, 14 breaths a minute, a VO₂max of 23
/// and a two-point `[0, 0]` bar strip. A chart is a claim about history, and
/// those are claims about a history that was never measured.
///
/// So every series here is the payload's own, unpadded. A series with fewer than
/// two points draws nothing, inside a slot that keeps its height — the tile does
/// not move, and the line that was never measured is not drawn. That is the
/// honesty exception the port is allowed, applied to state rather than layout.
///
/// ## Readings, not doubles
///
/// Legacy reads `double?` and prints `'—'`. Every figure here is a [Reading], so
/// a value the server withheld renders as a hole with its reason instead of as a
/// dash that could equally mean zero, missing, or broken.
library;

import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/features/today/today_baseline.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:meta/meta.dart';

/// The figures, series and labels one render of Today is built from.
@immutable
class TodayFacts {
  /// Prefer [TodayFacts.of].
  const TodayFacts({
    required this.snapshot,
    required this.now,
    required this.restingHeartRate,
    required this.heartRateVariability,
    required this.heartRateVariabilityBaseline,
    required this.heartRateVariabilityBaselineSd,
    required this.steps,
    required this.activeEnergy,
    required this.basalEnergy,
    required this.totalEnergy,
    required this.respiratoryRate,
    required this.bloodOxygen,
    required this.sleepDurationMin,
    required this.sleepScore,
    required this.sleepTotals,
    required this.sleepNight,
    required this.staleSleep,
  });

  /// Works the whole lot out from one payload.
  factory TodayFacts.of(TodaySnapshot snapshot, DateTime now) {
    final signals = snapshot.recoverySignals.valueOrNull;
    // Resolved ONCE, and both halves together — `today_baseline.dart` argues
    // why a centre from one carrier and a spread from the other is a pair
    // that was never measured.
    final hrv = Baseline.of(
      snapshot,
      signals,
      TodayMetricIds.heartRateVariability,
      'HRV',
    );
    final sleep = snapshot.lastSleep.valueOrNull;
    final endIso = sleep?.endIso;
    return TodayFacts(
      snapshot: snapshot,
      now: now,
      // Legacy's chains, in legacy's order (today_screen.dart:128–135).
      restingHeartRate: _chain(
        snapshot,
        const ['rhr_daily'],
        signals,
        'Resting',
      ),
      heartRateVariability: _chain(
        snapshot,
        const ['hrv_sleep_avg', 'hrv_rmssd_ms'],
        signals,
        'HRV',
      ),
      heartRateVariabilityBaseline: hrv.median,
      heartRateVariabilityBaselineSd: hrv.sd,
      steps: _chain(snapshot, const ['steps_total'], signals, null),
      activeEnergy: _chain(
        snapshot,
        const ['active_calories', 'total_calories'],
        signals,
        null,
      ),
      basalEnergy: snapshot.metric('basal_calories')?.reading.valueOrNull,
      totalEnergy: snapshot.metric('total_calories')?.reading.valueOrNull,
      // These two take a fourth source that the other four do not need, and it
      // is not an enhancement — without it they were permanently withheld. See
      // `_overnight`.
      respiratoryRate: _chain(
        snapshot,
        const ['respiratory_rate_sleep'],
        signals,
        null,
        overnight: _overnight(snapshot, endIso, now, (v) => v.respiratoryRate),
      ),
      bloodOxygen: _chain(
        snapshot,
        const ['spo2_overnight', 'spo2_sleep_avg'],
        signals,
        null,
        overnight: _overnight(snapshot, endIso, now, (v) => v.spo2Avg),
      ),
      sleepDurationMin: snapshot.lastSleep.map((night) => night.durationMin),
      sleepScore: sleep?.score,
      sleepTotals: sleep?.totals ?? const <String, int>{},
      sleepNight: sleepNightLabel(endIso, now),
      staleSleep: noSleepLastNight(endIso, now),
    );
  }

  /// The payload every field below came out of. Kept so a card can reach a block
  /// this class has no opinion about (`mvpa`, `vo2max`) without a second parse.
  final TodaySnapshot snapshot;

  /// The instant staleness is measured against.
  final DateTime now;

  /// `rhr_daily`, or the Resting marker on the recovery ladder.
  final Reading<double> restingHeartRate;

  /// `hrv_sleep_avg` → `hrv_rmssd_ms` → the HRV marker.
  final Reading<double> heartRateVariability;

  /// The owner's own normal for overnight HRV — **the server's, or nothing**.
  ///
  /// Null is a real and expected answer, and the HRV chart draws no baseline
  /// line when it comes back null rather than inventing one. See [_baseline].
  final double? heartRateVariabilityBaseline;

  /// The spread of that same window — the server's, or nothing.
  ///
  /// Paired with [heartRateVariabilityBaseline] and resolved from the same
  /// carrier, so the centre and the ± beside it were measured together — see
  /// `today_baseline.dart`, which argues why that is not optional.
  final double? heartRateVariabilityBaselineSd;

  /// `steps_total`.
  final Reading<double> steps;

  /// `active_calories`, falling back to `total_calories` as legacy does.
  final Reading<double> activeEnergy;

  /// `basal_calories`. A plain double: it only ever appears inside the Energy
  /// tile's foot, beside [totalEnergy], and legacy prints that foot only when
  /// **both** are present — there is no slot for a refusal in a foot line.
  final double? basalEnergy;

  /// `total_calories`, for the same foot.
  final double? totalEnergy;

  /// `respiratory_rate_sleep`, falling back to `last_sleep_extras`.
  final Reading<double> respiratoryRate;

  /// `spo2_overnight` → `spo2_sleep_avg` → `last_sleep_extras`.
  final Reading<double> bloodOxygen;

  /// Last night's total sleep time, minutes.
  final Reading<int> sleepDurationMin;

  /// The strap's own sleep score for that night, 0–100.
  final int? sleepScore;

  /// Minutes per stage for that night — the Sleep tile's foot **and its chart**.
  ///
  /// One field feeding both is the point: `HStageBar` draws these exact minutes
  /// in proportion and `stageFoot` prints the same two percentages under it, so
  /// the picture and the caption cannot disagree about the night.
  final Map<String, int> sleepTotals;

  /// "Last night" · "Night before last" · "3 nights ago".
  final String sleepNight;

  /// Whether every overnight reading below is from an older night.
  final bool staleSleep;

  /// One sparkline as plain values, oldest first. Never padded — see the library
  /// docstring.
  List<double> spark(String metric) => [
    for (final point in snapshot.sparkline(metric)) point.value,
  ];

  /// Today's step strip, 15 minutes to a bar.
  List<double> get stepStrip => [
    for (final bucket in snapshot.stepBuckets) bucket.steps,
  ];

  /// Today's heart rate, hour by hour — legacy's `hr24`.
  List<double> get heartRateDay => [
    for (final point in snapshot.hourlyHeartRate) point.average,
  ];

  /// Today's stress, hour by hour.
  List<double> get stressDay => [
    for (final point in snapshot.hourlyStress) point.average,
  ];

  /// The 30-day median for a metric, or null when there is none.
  double? median(String metric) => snapshot.metric(metric)?.median30d;

  /// That window's robust standard deviation, or null when the server sent none.
  double? spread(String metric) => snapshot.metric(metric)?.sd30d;

  /// The z-score for a metric, or null.
  double? standardScore(String metric) => snapshot.metric(metric)?.z;

  /// `MED 55` / `14-DAY TREND` under a tile.
  String medianFootFor(String metric) => medianFoot(median(metric));

  /// Whether this metric's z-score points the favourable way.
  bool? favorableFor(String metric) =>
      favorableDirection(metric, standardScore(metric));

  /// The first candidate that carried a value, else the first candidate's own
  /// refusal, else the recovery ladder, else an unexplained absence.
  ///
  /// The order matters and it is legacy's: legacy's `??` chain takes the first
  /// candidate whose VALUE is non-null, so a card that exists but was withheld
  /// does not shadow the next candidate. What legacy could not do is keep the
  /// refusal when nothing later answers either — its chain collapsed to `null`
  /// and printed a dash.
  static Reading<double> _chain(
    TodaySnapshot snapshot,
    List<String> candidates,
    RecoverySignals? signals,
    String? signalContains, {
    Reading<double>? overnight,
  }) {
    Reading<double>? firstRefusal;
    for (final id in candidates) {
      final card = snapshot.metric(id);
      if (card == null) {
        continue;
      }
      if (card.reading.hasValue) {
        return card.reading;
      }
      firstRefusal ??= card.reading;
    }
    if (signalContains != null && signals != null) {
      final marker = signalIn(signals, signalContains);
      if (marker?.value case final double value) {
        // Wrapped as `Present` and not as something softer: the server put this
        // number on the recovery ladder itself, so it is a measurement it is
        // already willing to show — just in a different block.
        return Present<double>(value);
      }
    }
    // AFTER the recorded refusal, not before. If the server sent a card and
    // refused to fill it, that refusal is a decision — "not enough overnight
    // samples" — and letting an unbounded raw average walk in behind it would
    // defeat a server gate on the last hop, which is the one failure
    // `data/honesty/reading.dart` exists to make impossible. The fallback is for
    // a metric the payload has NO card for at all, which is these two today.
    return firstRefusal ??
        (overnight?.hasValue ?? false ? overnight! : _absent);
  }

  /// The overnight vitals block as a last resort, **with its instrument named**.
  ///
  /// ## The bug this exists for
  ///
  /// The Resp and SpO₂ tiles read the `metrics` array, and `metrics` is built
  /// from `read/meta.py::TODAY_SECONDARY_METRICS` — seven slots, none of them
  /// respiratory or SpO₂. So `_chain` fell through every candidate, found no
  /// recovery marker to rescue it (`recovery_signals` carries exactly three:
  /// Resting HR, Sleep duration, Overnight HRV), and returned [_absent]. Both
  /// surfaces have therefore rendered **withheld since the port and would have
  /// forever** — a card permanently saying "no value, and the server did not
  /// say why" about numbers the same payload was carrying.
  ///
  /// The tell is that their CHARTS drew fine: `sparklines` does back both ids,
  /// so the blood-oxygen module rendered a fortnight of real data with a hole
  /// where its headline figure should be, and the Resp tile did the same.
  ///
  /// ## Why the value arrives caveated rather than present
  ///
  /// `last_sleep_extras` is not the same number as `derived_daily`. It is a raw
  /// `AVG` over the session window (`read/sleep_extras.py`), where the derived
  /// metric is a bounded window mean — and it carries **no honesty envelope, no
  /// provenance and no date**. CLAUDE.md's "ONE canonical definition per metric"
  /// is exactly the rule that makes silently swapping one for the other wrong.
  ///
  /// So it is not swapped silently. It is the last link in the chain, so a
  /// derived value always wins where one exists, and it arrives as [Caveated]
  /// with a sentence naming the instrument and the night — which is what
  /// "keep the instrument naming honest" has to mean for a block that names
  /// none of its own. The sentence rides with the value through `ReadingView`
  /// and `MetricTile` without either being asked.
  ///
  /// The real fix is a server one: add the two ids to `TODAY_SECONDARY_METRICS`
  /// with their `METRIC_META` rows, and the tiles get medians, z-scores and
  /// delta badges for free from the same path the working four use. That needs
  /// a contract snapshot, so it is a server PR. This stops the app lying in the
  /// meantime, and disappears on its own the day the server sends the card —
  /// the derived value takes precedence in the chain above.
  static Reading<double>? _overnight(
    TodaySnapshot snapshot,
    String? endIso,
    DateTime now,
    double? Function(OvernightVitals vitals) pick,
  ) {
    final vitals = snapshot.overnightVitals;
    if (vitals == null) {
      return null;
    }
    final value = pick(vitals);
    if (value == null) {
      return null;
    }
    final night = sleepNightLabel(endIso, now).toLowerCase();
    return Caveated<double>(value, <Disclosure>[
      Disclosure(
        reason: 'overnight_session_mean',
        message:
            'Measured over your sleep session $night, as a plain average of the '
            'strap’s overnight samples. It is not the bounded daily figure the '
            'other cards show, and it is not today.',
      ),
    ]);
  }

  /// What a metric with no card and no marker resolves to. The same sentence
  /// `readingFrom` gives an absent block, so one absence reads one way.
  static final Reading<double> _absent = readingFrom<double>(
    const <String, Object?>{},
    (_) => null,
  );
}

/// The metric ids the six grid tiles are keyed by, in legacy's order.
///
/// Named so `metric_hue.dart` and the delta badges are looked up by the same
/// string the payload uses, rather than by a label that could be re-worded.
abstract final class TodayMetricIds {
  /// The Sleep tile.
  static const String sleep = 'sleep';

  /// The Resting HR tile.
  static const String restingHeartRate = 'rhr_daily';

  /// The HRV tile.
  static const String heartRateVariability = 'hrv_sleep_avg';

  /// The Steps tile.
  static const String steps = 'steps_total';

  /// The Energy tile.
  static const String activeEnergy = 'active_calories';

  /// The Respiratory rate tile.
  static const String respiratoryRate = 'respiratory_rate_sleep';

  /// The overnight blood-oxygen module.
  static const String bloodOxygen = 'spo2_overnight';

  /// The nightly minimum behind it.
  static const String bloodOxygenMin = 'spo2_overnight_min';

  /// The daily stress trend.
  static const String stress = 'stress';
}
