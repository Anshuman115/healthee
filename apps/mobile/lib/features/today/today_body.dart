/// Today's body, from the recovery card down — composition only.
///
/// Split out of `today_sections.dart` at the 400-line gate (Standards §1). The
/// seam is deliberate and it is not arbitrary: `today_sections.dart` owns the
/// **head** of the screen — the things that are true before any number is read
/// (the greeting, the data-health card, the illness flag) and the two states
/// that replace the whole body (a fresh install, an unreachable server). This
/// file owns the instruments.
///
/// The ORDER across the seam is unbroken, and `test/features/today_order_test.dart`
/// asserts it against legacy's own list rather than against either file.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/data/models/strength.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/widgets/actions_section.dart';
import 'package:healthee/features/today/widgets/bio_age_card.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/cardio_load_card.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/hrv_trend_card.dart';
import 'package:healthee/features/today/widgets/insights_section.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/features/today/widgets/mvpa_card.dart';
import 'package:healthee/features/today/widgets/readiness_block.dart';
import 'package:healthee/features/today/widgets/recovery_card.dart';
import 'package:healthee/features/today/widgets/recovery_signals_card.dart';
import 'package:healthee/features/today/widgets/routine_card.dart';
import 'package:healthee/features/today/widgets/seven_night_card.dart';
import 'package:healthee/features/today/widgets/sleep_debt_card.dart';
import 'package:healthee/features/today/widgets/sleep_health_card.dart';
import 'package:healthee/features/today/widgets/stale_sleep_banner.dart';
import 'package:healthee/features/today/widgets/strength_card.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/features/today/widgets/today_tiles.dart';
import 'package:healthee/features/today/widgets/vo2max_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// Everything from the recovery card down. Split out only so neither half is a
/// forty-line function (Standards §1); the order across the seam is unbroken.
void todayBody(SectionList sections, TodayFacts facts, ScreenData data) {
  final snapshot = facts.snapshot;
  final reveals = data.reveals;
  final tiles = TodayTiles(facts: facts, reveals: reveals);

  sections.add(
    ReadingView<RecoveryScore>(
      reading: snapshot.recovery,
      label: 'Recovery',
      builder: (context, score) => RecoveryCard(score: score, reveals: reveals),
    ),
  );
  sections.gap(10);
  sections.add(
    ReadingView<RecoverySignals>(
      reading: snapshot.recoverySignals,
      label: 'Recovery signals',
      builder: (context, signals) => RecoverySignalsCard(signals: signals),
    ),
  );
  sections.gap(10);
  if (snapshot.recommendations.isNotEmpty || snapshot.action != null) {
    sections.add(
      ActionsSection(
        recommendations: snapshot.recommendations,
        // `/api/today.action` — a model-written line legacy renders nowhere.
        action: snapshot.action,
      ),
    );
    sections.gap(24);
  }
  sections.add(
    Builder(
      builder: (context) => MetricTileRow(
        left: tiles.restingHeartRate(context),
        right: tiles.heartRateVariability(context),
      ),
    ),
  );
  final hrvSpark = facts.spark(TodayMetricIds.heartRateVariability);
  if (hrvSpark.length > 2) {
    sections.gap(10);
    sections.add(
      HrvTrendCard(
        series: hrvSpark,
        reading: facts.heartRateVariability,
        // NOT `facts.median('hrv_sleep_avg')`, which is null on every payload:
        // the server baselines this metric but gives it no metric card. See
        // `TodayFacts._hrvBaseline`.
        baseline: facts.heartRateVariabilityBaseline,
        reveals: reveals,
      ),
    );
  }
  final stressDaily = facts.spark(TodayMetricIds.stress);
  if (StressCard.hasSomethingToDraw(facts.stressDay, stressDaily)) {
    sections.gap(10);
    sections.add(
      StressCard(
        intraday: facts.stressDay,
        daily: stressDaily,
        reveals: reveals,
      ),
    );
  }
  final heartRateDay = facts.heartRateDay;
  if (heartRateDay.length > 2) {
    sections.gap(10);
    sections.add(
      HeartRateDayCard(
        points: snapshot.hourlyHeartRate,
        restingHeartRate: facts.restingHeartRate,
        reveals: reveals,
      ),
    );
  }
  sleepSections(sections, facts, tiles, reveals);
  activitySections(sections, facts, tiles, reveals);
  fitnessSections(sections, facts, reveals);
  if (snapshot.findings.isNotEmpty) {
    sections.gap(24);
    sections.add(const SectionHeading('Insights'));
    sections.add(InsightsSection(findings: snapshot.findings));
  }
}

void sleepSections(
  SectionList sections,
  TodayFacts facts,
  TodayTiles tiles,
  RevealRegistry reveals,
) {
  final snapshot = facts.snapshot;
  sections.gap(24);
  sections.add(const SectionHeading('Sleep'));
  if (facts.staleSleep) {
    sections.add(StaleSleepBanner(nightLabel: facts.sleepNight));
    sections.gap(10);
  }
  sections.add(
    ReadinessBlock(
      sleepScore: facts.sleepScore,
      durationMin: facts.sleepDurationMin,
      nightLabel: facts.sleepNight,
      reveals: reveals,
    ),
  );
  sections.gap(10);
  sections.add(
    Builder(
      builder: (context) => MetricTileRow(
        left: tiles.sleep(context),
        right: tiles.respiratoryRate(context),
      ),
    ),
  );
  // Legacy gates this module on its DRAWN series having more than two points,
  // and the drawn series is the nightly minimums now (see the card). The two
  // sparklines arrive together in practice — `derive/hrv_spo2_resp.py` writes
  // both from one window or writes neither — so this is legacy's gate applied
  // to legacy's rule, not a narrower one.
  final oxygenMinima = facts.spark(TodayMetricIds.bloodOxygenMin);
  if (oxygenMinima.length > 2) {
    sections.gap(10);
    sections.add(
      BloodOxygenCard(
        minima: oxygenMinima,
        reading: facts.bloodOxygen,
        reveals: reveals,
      ),
    );
  }
  sections.gap(10);
  sections.add(
    ReadingView<SleepDebt>(
      reading: snapshot.sleepDebt,
      label: 'Sleep need · debt',
      builder: (context, debt) => SleepDebtCard(debt: debt, reveals: reveals),
    ),
  );
  sections.gap(10);
  sections.add(
    ReadingView<SleepHealth>(
      reading: snapshot.sleepHealth,
      label: 'Sleep health · 4-dim',
      builder: (context, health) => SleepHealthCard(health: health),
    ),
  );
  if (snapshot.sleepHistory7d.length >= 2) {
    sections.gap(10);
    sections.add(
      SevenNightCard(nights: snapshot.sleepHistory7d, reveals: reveals),
    );
  }
}

void activitySections(
  SectionList sections,
  TodayFacts facts,
  TodayTiles tiles,
  RevealRegistry reveals,
) {
  sections.gap(24);
  sections.add(const SectionHeading('Activity'));
  sections.add(
    Builder(
      builder: (context) => MetricTileRow(
        left: tiles.steps(context),
        right: tiles.energy(context),
      ),
    ),
  );
  sections.gap(10);
  sections.add(
    ReadingView<CardioLoad>(
      reading: facts.snapshot.cardioLoad,
      label: 'Strain · cardio load',
      builder: (context, load) => CardioLoadCard(load: load, reveals: reveals),
    ),
  );
  sections.gap(10);
  sections.add(
    ReadingView<Mvpa>(
      reading: facts.snapshot.mvpa,
      label: 'Active minutes · MVPA',
      builder: (context, mvpa) => MvpaCard(mvpa: mvpa, reveals: reveals),
    ),
  );
  // Added, not legacy's — the other half of the same recommendation.
  if (facts.snapshot.strength case final Strength strength) {
    sections.gap(10);
    sections.add(StrengthCard(strength: strength, reveals: reveals));
  }
  // Added, not legacy's. A day with nothing logged draws nothing at all.
  if (!facts.snapshot.routine.isEmpty) {
    sections.gap(10);
    sections.add(RoutineCard(routine: facts.snapshot.routine));
  }
}

void fitnessSections(
  SectionList sections,
  TodayFacts facts,
  RevealRegistry reveals,
) {
  sections.gap(24);
  sections.add(const SectionHeading('Fitness'));
  sections.add(
    ReadingView<BiologicalAge>(
      reading: facts.snapshot.biologicalAge,
      label: 'Biological age · estimate',
      builder: (context, age) => BioAgeCard(age: age, reveals: reveals),
    ),
  );
  sections.gap(10);
  sections.add(
    ReadingView<Vo2max>(
      reading: facts.snapshot.vo2max,
      label: 'VO₂max · estimate',
      builder: (context, vo2max) =>
          Vo2maxCard(vo2max: vo2max, reveals: reveals),
    ),
  );
}
