/// The ordered sections of Today. Composition only — no widget is defined here.
///
/// ## The shape is the legacy app's, and it is an index over entries
///
/// `design_reference/project/hh/screen_today.jsx` opens with a header, an
/// editorial line, a readiness instrument and a dense two-column grid, and only
/// then goes long. That opening is what this rebuild is for: the screen it
/// replaced was a column of one large card per metric, which is legible and slow
/// and looks nothing like the design the owner approved.
///
/// The grid is an **index**, and the sections under it are the **entries**.
/// Legacy could afford six terse modules because each one opened a detail sheet;
/// this app has no sheets yet, so the detail is the rest of the scroll. The two
/// halves are not duplicates in any sense that can drift — a grid cell and its
/// section read the *same field of the same object*, and the cell is deliberately
/// the one that carries less.
///
/// That pairing is load-bearing rather than cosmetic. `grid_module.dart` explains
/// why a 118 px cell shows a hole and the word WITHHELD but never a refusal's
/// reason or its remedy; the reason it is allowed to do that is that the section
/// owning the metric is **always** on this list and always renders the full
/// `WithheldCard`. Removing one of those sections silently downgrades a refusal
/// into a shrug. `metric_grid.dart` names the pairing slot by slot.
///
/// ## Two departures from legacy's own list, both because the payload decides
///
///   * **"Today's focus" was active challenges.** `/api/today` carries no
///     challenges, so the slot is not drawn at all rather than filled with a
///     placeholder.
///   * **The illness flag comes early, not last.** It is deterministic and
///     safety-critical and brief §4.1 says it outranks everything; data health
///     stays above it only because it renders nothing at all when things are
///     well. Both sit above the grid, so nothing on this screen can be read
///     before the flag that overrides it.
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
import 'package:healthee/core/theme/dimensions.dart';
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
import 'package:healthee/features/today/widgets/greeting_block.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/features/today/widgets/metric_grid.dart';
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
import 'package:healthee/features/today/widgets/today_header.dart';
import 'package:healthee/features/today/widgets/vo2max_card.dart';
import 'package:healthee/features/today/widgets/workouts_card.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// The gap under a section. Legacy's modules sit 10 px apart and its section
/// breaks are much wider; [TodaySpacing] carries that difference so the screen
/// does not pad everything to one rhythm and lose the grouping.
abstract final class TodaySpacing {
  /// Between two cards in the same section.
  static const double card = Insets.md;

  /// Under the last card of a section, before the next heading.
  static const double section = Insets.xl;
}

/// One entry in the Today list: a widget and the gap that follows it.
@immutable
class TodaySection {
  /// A section [child] followed by [gap] of space.
  const TodaySection(this.child, {this.gap = TodaySpacing.card});

  /// What to draw.
  final Widget child;

  /// The space under it.
  final double gap;
}

/// Builds the ordered section list for one render of Today.
///
/// A plain function rather than a widget: it decides ORDER, and order is not a
/// thing that needs an element in the tree. Everything it returns is a widget
/// defined in its own file.
List<TodaySection> todaySections({
  required DeviceDay day,
  required RevealRegistry reveals,
  TodayView? server,
  PushStamp? push,
  DateTime? now,
  bool? signedIn,
  VoidCallback? onSignIn,
}) {
  final snapshot = server?.snapshot;
  final recovery = snapshot?.recovery.valueOrNull;
  return <TodaySection>[
    TodaySection(TodayHeader(now: now), gap: Insets.lg),
    TodaySection(
      GreetingBlock(guidance: recovery?.guidance, now: now),
      gap: TodaySpacing.section,
    ),

    // Above everything a number could be read from, and silent when all is well.
    TodaySection(
      DataHealthSection(
        health: snapshot?.dataHealth,
        push: push,
        cachedAt: server != null && server.fromCache ? server.fetchedAt : null,
        cachedDate: server != null && server.describesAnotherDay(day.date)
            ? snapshot?.date
            : null,
        now: now,
        signedIn: signedIn,
        onSignIn: onSignIn,
      ),
    ),
    if (snapshot?.illnessFlag case final flag?) TodaySection(IllnessBanner(flag: flag)),

    // ── the instrument head ────────────────────────────────────────────────
    if (snapshot != null)
      TodaySection(
        ReadingView<RecoveryScore>(
          reading: snapshot.recovery,
          label: 'Recovery',
          builder: (context, score) =>
              RecoveryCard(score: score, reveals: reveals),
        ),
      ),
    TodaySection(MetricGrid(day: day, reveals: reveals, snapshot: snapshot)),
    TodaySection(HeartRateCard(day: day, reveals: reveals, now: now)),
    if (snapshot != null)
      TodaySection(
        StressCard(hours: snapshot.hourlyStress, reveals: reveals),
        gap: TodaySpacing.section,
      ),
    if (snapshot != null)
      TodaySection(
        DailyActionCard(
          action: snapshot.action,
          recommendations: snapshot.recommendations,
        ),
        gap: TodaySpacing.section,
      ),

    // ── the entries ────────────────────────────────────────────────────────
    const TodaySection(SectionHeading('Recovery & heart')),
    if (snapshot != null)
      TodaySection(
        ReadingView<RecoverySignals>(
          reading: snapshot.recoverySignals,
          label: 'Recovery signals',
          builder: (context, signals) => RevealOnce(
            id: 'recovery-ladder',
            registry: reveals,
            builder: (context, t) => RecoveryLadder(signals: signals, progress: t),
          ),
        ),
        gap: TodaySpacing.section,
      ),

    const TodaySection(
      SectionHeading('Sleep', subtitle: 'Last night, and the week behind it'),
    ),
    // The server's staged night when it has one, the strap's own when it does
    // not. Not a fallback dressed as the same card: each says which instrument
    // it came from, and with no network at all the owner still sees the night
    // their phone read (brief §7.4). Showing the server's judgements beside the
    // server's copy of the night is what keeps the two from disagreeing.
    if (snapshot != null && snapshot.lastSleep.hasValue)
      TodaySection(
        ReadingView<LastSleep>(
          reading: snapshot.lastSleep,
          label: 'Last night',
          builder: (context, night) => SleepNightCard(
            night: night,
            reveals: reveals,
            vitals: snapshot.overnightVitals,
          ),
        ),
      )
    else
      TodaySection(SleepCard(day: day, now: now)),
    if (snapshot != null)
      TodaySection(
        ReadingView<SleepHealth>(
          reading: snapshot.sleepHealth,
          label: 'Sleep health',
          builder: (context, health) => SleepDimensionsCard(health: health),
        ),
      ),
    if (snapshot != null)
      TodaySection(
        ReadingView<SleepDebt>(
          reading: snapshot.sleepDebt,
          label: 'Sleep debt',
          builder: (context, debt) => SleepDebtCard(
            debt: debt,
            nights: snapshot.sleepHistory7d,
            reveals: reveals,
          ),
        ),
      ),
    if (snapshot != null)
      TodaySection(SleepWeekCard(nights: snapshot.sleepHistory7d, reveals: reveals)),
    if (snapshot?.overnightVitals case final vitals?)
      TodaySection(
        BloodOxygenCard(
          vitals: vitals,
          nightlyMinimums: snapshot!.sparkline('spo2_overnight_min'),
          reveals: reveals,
        ),
        gap: TodaySpacing.section,
      ),

    const TodaySection(SectionHeading('Activity')),
    TodaySection(StepsCard(day: day, now: now)),
    if (snapshot != null)
      TodaySection(
        ReadingView<CardioLoad>(
          reading: snapshot.cardioLoad,
          label: 'Cardio load',
          builder: (context, load) => CardioLoadCard(load: load, reveals: reveals),
        ),
      ),
    if (snapshot != null)
      TodaySection(
        ReadingView<Mvpa>(
          reading: snapshot.mvpa,
          label: 'Active minutes',
          builder: (context, mvpa) => MvpaCard(mvpa: mvpa, reveals: reveals),
        ),
      ),
    TodaySection(WorkoutsCard(workouts: day.workouts), gap: TodaySpacing.section),

    const TodaySection(SectionHeading('Fitness')),
    if (snapshot != null)
      TodaySection(
        ReadingView<BiologicalAge>(
          reading: snapshot.biologicalAge,
          label: 'Biological age',
          builder: (context, age) => BiologicalAgeCard(age: age),
        ),
      ),
    if (snapshot != null)
      TodaySection(
        ReadingView<Vo2max>(
          reading: snapshot.vo2max,
          label: 'VO₂max',
          builder: (context, vo2max) => Vo2maxCard(vo2max: vo2max, reveals: reveals),
        ),
        gap: TodaySpacing.section,
      ),

    if (snapshot != null && snapshot.findings.isNotEmpty) ...[
      const TodaySection(SectionHeading('Insights')),
      TodaySection(
        FindingsSection(findings: snapshot.findings),
        gap: TodaySpacing.section,
      ),
    ],

    if (snapshot != null && snapshot.metrics.isNotEmpty) ...[
      const TodaySection(SectionHeading('Baselines')),
      TodaySection(
        ServerMetricStrip(
          metrics: snapshot.metrics,
          sparklines: snapshot.sparklines,
          reveals: reveals,
        ),
        gap: TodaySpacing.section,
      ),
    ],

    const TodaySection(
      SectionHeading(
        'From the strap',
        subtitle: 'What this phone read off the device, with nothing added',
      ),
    ),
    TodaySection(MetricStrip(metrics: day.metrics, now: now)),
    TodaySection(DeviceHealthCard(day: day, now: now)),
  ];
}
