/// The ordered sections of Today. Composition only — no widget is defined here.
///
/// ## The order is legacy's, and it is the product of real use
///
/// `~/projects/healthee-legacy/app/lib/ui/today_screen.dart` organised Today in
/// domain sections — data health, focus, recovery & heart, sleep, activity,
/// fitness, insights — and that ordering survived a year of daily use. It is
/// kept. What is not kept is that file's shape: 1,571 lines of screen is exactly
/// what Engineering Standards §1 exists to prevent, so the layout is a list of
/// widgets here and every module lives in its own file under `widgets/`.
///
/// Two departures from the legacy list, both because the payload decides:
///
///   * **"Today's focus" was active challenges.** `/api/today` carries no
///     challenges, so the slot is not drawn at all rather than filled with a
///     placeholder. The daily action and the cited recommendations take the
///     position, which is where brief §4.1 puts them anyway.
///   * **The illness flag comes second, not last.** It is deterministic and
///     safety-critical and brief §4.1 says it outranks everything; data health
///     stays above it only because it renders nothing at all when things are
///     well.
///
/// ## Two sources, one screen
///
/// Measured things come from the phone's own store and render with no network;
/// derived things come from `/api/today`. Where both hold a version of the same
/// night, the SERVER's is drawn beside the server's judgements — a judgement
/// shown next to a different copy of the night it was computed from is how two
/// numbers start disagreeing.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/recovery_signals.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/features/today/widgets/biological_age_card.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/cardio_load_card.dart';
import 'package:healthee/features/today/widgets/daily_action_card.dart';
import 'package:healthee/features/today/widgets/data_health_section.dart';
import 'package:healthee/features/today/widgets/device_health_card.dart';
import 'package:healthee/features/today/widgets/findings_section.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/features/today/widgets/metric_strip.dart';
import 'package:healthee/features/today/widgets/mvpa_card.dart';
import 'package:healthee/features/today/widgets/recovery_card.dart';
import 'package:healthee/features/today/widgets/recovery_ladder.dart';
import 'package:healthee/features/today/widgets/section_heading.dart';
import 'package:healthee/features/today/widgets/server_metric_strip.dart';
import 'package:healthee/features/today/widgets/sleep_card.dart';
import 'package:healthee/features/today/widgets/sleep_debt_card.dart';
import 'package:healthee/features/today/widgets/sleep_dimensions_card.dart';
import 'package:healthee/features/today/widgets/sleep_night_card.dart';
import 'package:healthee/features/today/widgets/sleep_week_card.dart';
import 'package:healthee/features/today/widgets/steps_card.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/features/today/widgets/vo2max_card.dart';
import 'package:healthee/features/today/widgets/workouts_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// Builds the ordered section list for one render of Today.
///
/// A plain function rather than a widget: it decides ORDER, and order is not a
/// thing that needs an element in the tree. Everything it returns is a widget
/// defined in its own file.
List<Widget> todaySections({
  required DeviceDay day,
  required RevealRegistry reveals,
  TodayView? server,
  PushStamp? push,
  DateTime? now,
}) {
  final snapshot = server?.snapshot;
  return <Widget>[
    DataHealthSection(
      health: snapshot?.dataHealth,
      push: push,
      cachedAt: server != null && server.fromCache ? server.fetchedAt : null,
      cachedDate: server != null && server.describesAnotherDay(day.date)
          ? snapshot?.date
          : null,
      now: now,
    ),
    if (snapshot?.illnessFlag case final flag?) IllnessBanner(flag: flag),
    if (snapshot != null)
      DailyActionCard(
        action: snapshot.action,
        recommendations: snapshot.recommendations,
      ),

    const SectionHeading('Recovery & heart'),
    if (snapshot != null)
      ReadingView<RecoveryScore>(
        reading: snapshot.recovery,
        label: 'Recovery',
        builder: (context, score) => RecoveryCard(score: score),
      ),
    if (snapshot != null)
      ReadingView<RecoverySignals>(
        reading: snapshot.recoverySignals,
        label: 'Recovery signals',
        builder: (context, signals) => RevealOnce(
          id: 'recovery-ladder',
          registry: reveals,
          builder: (context, t) =>
              RecoveryLadder(signals: signals, progress: t),
        ),
      ),
    HeartRateCard(day: day, reveals: reveals, now: now),
    if (snapshot != null)
      StressCard(hours: snapshot.hourlyStress, reveals: reveals),

    const SectionHeading('Sleep', subtitle: 'Last night, and the week behind it'),
    // The server's staged night when it has one, the strap's own when it does
    // not. Not a fallback dressed as the same card: each says which instrument
    // it came from, and with no network at all the owner still sees the night
    // their phone read (brief §7.4). Showing the server's judgements beside the
    // server's copy of the night is what keeps the two from disagreeing.
    if (snapshot != null && snapshot.lastSleep.hasValue)
      ReadingView<LastSleep>(
        reading: snapshot.lastSleep,
        label: 'Last night',
        builder: (context, night) => SleepNightCard(
          night: night,
          reveals: reveals,
          vitals: snapshot.overnightVitals,
        ),
      )
    else
      SleepCard(day: day, now: now),
    if (snapshot != null)
      ReadingView<SleepHealth>(
        reading: snapshot.sleepHealth,
        label: 'Sleep health',
        builder: (context, health) => SleepDimensionsCard(health: health),
      ),
    if (snapshot != null)
      ReadingView<SleepDebt>(
        reading: snapshot.sleepDebt,
        label: 'Sleep debt',
        builder: (context, debt) => SleepDebtCard(
          debt: debt,
          nights: snapshot.sleepHistory7d,
          reveals: reveals,
        ),
      ),
    if (snapshot != null)
      SleepWeekCard(nights: snapshot.sleepHistory7d, reveals: reveals),
    if (snapshot?.overnightVitals case final vitals?)
      BloodOxygenCard(
        vitals: vitals,
        nightlyMinimums: snapshot!.sparkline('spo2_overnight_min'),
        reveals: reveals,
      ),

    const SectionHeading('Activity'),
    StepsCard(day: day, now: now),
    if (snapshot != null)
      ReadingView<CardioLoad>(
        reading: snapshot.cardioLoad,
        label: 'Cardio load',
        builder: (context, load) =>
            CardioLoadCard(load: load, reveals: reveals),
      ),
    if (snapshot != null)
      ReadingView<Mvpa>(
        reading: snapshot.mvpa,
        label: 'Active minutes',
        builder: (context, mvpa) => MvpaCard(mvpa: mvpa, reveals: reveals),
      ),
    WorkoutsCard(workouts: day.workouts),

    const SectionHeading('Fitness'),
    if (snapshot != null)
      ReadingView<BiologicalAge>(
        reading: snapshot.biologicalAge,
        label: 'Biological age',
        builder: (context, age) => BiologicalAgeCard(age: age),
      ),
    if (snapshot != null)
      ReadingView<Vo2max>(
        reading: snapshot.vo2max,
        label: 'VO₂max',
        builder: (context, vo2max) =>
            Vo2maxCard(vo2max: vo2max, reveals: reveals),
      ),

    if (snapshot != null && snapshot.findings.isNotEmpty) ...[
      const SectionHeading('Insights'),
      FindingsSection(findings: snapshot.findings),
    ],

    if (snapshot != null && snapshot.metrics.isNotEmpty) ...[
      const SectionHeading('Baselines'),
      ServerMetricStrip(
        metrics: snapshot.metrics,
        sparklines: snapshot.sparklines,
        reveals: reveals,
      ),
    ],

    const SectionHeading(
      'From the strap',
      subtitle: 'What this phone read off the device, with nothing added',
    ),
    MetricStrip(metrics: day.metrics, now: now),
    DeviceHealthCard(day: day, now: now),
  ];
}
