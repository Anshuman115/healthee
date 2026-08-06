/// The six grid tiles, exactly as legacy defines them.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart:173–213` — the
/// six `_MetricModule`s built at the top of `_Content.build` and then placed into
/// three separate two-up rows further down. They are built here, in one place,
/// for the same reason legacy builds them in one place: the rows they sit in are
/// in three different sections of the screen, and a tile defined beside its row
/// would be three files agreeing about what a tile is.
///
/// Each function returns a [MetricTile]. Every hue, unit, chart type and foot is
/// legacy's, cited to its line.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/charts/h_stage_bar.dart';
import 'package:healthee/shared/reveal_once.dart';

/// Builds the six tiles for one render.
///
/// A class rather than six free functions so the facts and the registry are
/// passed once — six functions each taking both is six chances to hand one of
/// them a registry built locally, which silently breaks reveal-once.
class TodayTiles {
  /// [reveals] must be the screen's registry.
  const TodayTiles({required this.facts, required this.reveals});

  /// The figures and series this render draws from.
  final TodayFacts facts;

  /// Where "this chart has already animated" is remembered.
  final RevealRegistry reveals;

  /// `SLEEP · 6:20 hrs` with the night's stage proportions. Legacy 173.
  ///
  /// ## A DELIBERATE DEPARTURE FROM LEGACY — owner-delegated, decided 2026-08-06
  ///
  /// **Do not "restore" the hypnogram here.** Legacy draws
  /// `HHypnogram(..., height: 30)` in this cell and the port did too. At 30 px
  /// that is four lanes of ~7 px with a 62% band inside each, so on this owner's
  /// real nights — fragmented ones — every span is a 4 px sliver on its own row
  /// and the chart reads as scattered dots. The drawing was never wrong; the SIZE
  /// was wrong for it.
  ///
  /// The owner delegated the call and it was made: the tile draws [HStageBar],
  /// the stacked proportion bar, which spends the whole 30 px on one row so the
  /// smallest stage a real night carries is still several pixels tall. The stage
  /// colours are unchanged — the same `stage_colors.dart` table the hypnogram
  /// uses — so nothing about what deep sleep looks like moved.
  ///
  /// **The full hypnogram stays on the Sleep tab, at full width, unchanged**
  /// (`features/sleep/widgets/hypnogram_card.dart`). Proportion answers "how did
  /// the night divide"; it never answers "when", and this cell is a door to the
  /// screen that does.
  MetricTile sleep(BuildContext context) => MetricTile(
    label: 'Sleep',
    tag: context.hues.sleep,
    infoKey: 'sleep',
    reading: facts.sleepDurationMin.map((minutes) => minutes.toDouble()),
    format: (minutes) => clockDuration(minutes.round()),
    unit: 'hrs',
    foot: stageFoot(facts.sleepTotals),
    chart: RevealOnce(
      id: 'today.tile.sleep',
      registry: reveals,
      builder: (context, t) => Align(
        // The bar is 10 px inside the 30 px chart slot legacy sizes. The slot
        // keeps its height so the tile keeps its footprint, and the bar sits on
        // the baseline the hypnogram's lowest lane used.
        alignment: Alignment.bottomCenter,
        child: HStageBar(facts.sleepTotals, progress: t),
      ),
    ),
  );

  /// `RESTING HR · 55 bpm` over its 14-day line. Legacy 180.
  MetricTile restingHeartRate(BuildContext context) {
    final tint = context.hues.heart;
    return MetricTile(
      label: 'Resting HR',
      tag: tint,
      infoKey: 'rhr_daily',
      reading: facts.restingHeartRate,
      format: (value) => value.round().toString(),
      unit: 'bpm',
      foot: facts.medianFootFor(TodayMetricIds.restingHeartRate),
      delta: facts.standardScore(TodayMetricIds.restingHeartRate),
      deltaFavorable: facts.favorableFor(TodayMetricIds.restingHeartRate),
      chart: RevealOnce(
        id: 'today.tile.rhr',
        registry: reveals,
        builder: (context, t) => HArea(
          facts.spark(TodayMetricIds.restingHeartRate),
          color: tint,
          progress: t,
          height: MetricTile.chartHeight,
          unit: 'bpm',
        ),
      ),
    );
  }

  /// `HRV · 45 ms` over its 14-day bars. Legacy 186 — note that legacy tints the
  /// figure itself here, which it does for three of the six.
  MetricTile heartRateVariability(BuildContext context) {
    final tint = context.hues.hrv;
    return MetricTile(
      label: 'HRV',
      tag: tint,
      infoKey: 'hrv',
      valueColor: tint,
      reading: facts.heartRateVariability,
      format: (value) => value.round().toString(),
      unit: 'ms',
      foot: facts.medianFootFor(TodayMetricIds.heartRateVariability),
      delta: facts.standardScore(TodayMetricIds.heartRateVariability),
      deltaFavorable: facts.favorableFor(TodayMetricIds.heartRateVariability),
      chart: RevealOnce(
        id: 'today.tile.hrv',
        registry: reveals,
        builder: (context, t) => HBars(
          facts.spark(TodayMetricIds.heartRateVariability),
          color: tint,
          progress: t,
          height: MetricTile.chartHeight,
          unit: 'ms',
        ),
      ),
    );
  }

  /// `STEPS · 9,264` over today's 15-minute buckets. Legacy 192.
  ///
  /// This is the one tile whose chart is **today** rather than a fortnight,
  /// which is why every bar is highlighted: there is no "latest" to pick out of
  /// a day that is still happening.
  MetricTile steps(BuildContext context) {
    final tint = context.hues.steps;
    return MetricTile(
      label: 'Steps',
      tag: tint,
      infoKey: 'steps_total',
      reading: facts.steps,
      format: (value) => commaGrouped(value.round()),
      foot: facts.medianFootFor(TodayMetricIds.steps),
      delta: facts.standardScore(TodayMetricIds.steps),
      deltaFavorable: facts.favorableFor(TodayMetricIds.steps),
      chart: RevealOnce(
        id: 'today.tile.steps',
        registry: reveals,
        builder: (context, t) => HBars(
          facts.stepStrip,
          color: tint,
          progress: t,
          height: MetricTile.chartHeight,
          allHighlighted: true,
          unit: 'steps',
        ),
      ),
    );
  }

  /// `ENERGY · ACTIVE · 412 kcal`. Legacy 198.
  ///
  /// The foot names the resting and total figures when **both** are present and
  /// says `ACTIVE TODAY` otherwise, which is legacy's own condition: half of a
  /// breakdown is not a breakdown.
  MetricTile energy(BuildContext context) {
    final tint = context.hues.calories;
    final basal = facts.basalEnergy;
    final total = facts.totalEnergy;
    return MetricTile(
      label: 'Energy · active',
      tag: tint,
      infoKey: 'energy',
      valueColor: tint,
      reading: facts.activeEnergy,
      format: (value) => value.round().toString(),
      unit: 'kcal',
      foot: basal != null && total != null
          ? 'REST ${commaGrouped(basal.round())} · '
                'TOTAL ${commaGrouped(total.round())}'
          : 'ACTIVE TODAY',
      delta: facts.standardScore(TodayMetricIds.activeEnergy),
      deltaFavorable: facts.favorableFor(TodayMetricIds.activeEnergy),
      chart: RevealOnce(
        id: 'today.tile.energy',
        registry: reveals,
        builder: (context, t) => HArea(
          // Legacy's `spark['active_calories'] ?? spark['total_calories']`.
          facts.spark(TodayMetricIds.activeEnergy).isNotEmpty
              ? facts.spark(TodayMetricIds.activeEnergy)
              : facts.spark('total_calories'),
          color: tint,
          progress: t,
          height: MetricTile.chartHeight,
          unit: 'kcal',
        ),
      ),
    );
  }

  /// `RESPIRATORY RATE · 14 br/min`. Legacy 208.
  ///
  /// Its foot is a **population range**, not the owner's own median — the one
  /// tile whose context line is not personal. Legacy's, unchanged.
  MetricTile respiratoryRate(BuildContext context) {
    final tint = context.hues.respiratory;
    return MetricTile(
      label: 'Respiratory rate',
      tag: tint,
      infoKey: 'resp',
      valueColor: tint,
      reading: facts.respiratoryRate,
      format: (value) => value.round().toString(),
      unit: 'br/min',
      foot: 'RANGE 12–16 br/min',
      chart: RevealOnce(
        id: 'today.tile.respiratory',
        registry: reveals,
        builder: (context, t) => HArea(
          facts.spark(TodayMetricIds.respiratoryRate),
          color: tint,
          progress: t,
          height: MetricTile.chartHeight,
          unit: 'br',
        ),
      ),
    );
  }
}
