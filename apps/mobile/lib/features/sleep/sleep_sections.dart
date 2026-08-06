/// The Sleep tab's section list — **legacy's `children`, in legacy's order**.
///
/// `sleep_screen.dart:251–496` builds one flat `List<Widget>` and hands it to a
/// `ListView.builder` that wraps each entry in `HReveal`. This file is that list,
/// split so each card lives in its own file (Standards §3: a screen is
/// composition) without a single entry moving.
///
/// ```text
///   header                       ── the eyebrow, the word Sleep
///   Tonight                      ── when the plan includes it
///   no-sleep-last-night banner   ── when the latest session is over a day old
///   AI sleep analysis
///   hero: score + time asleep
///   ══ <night label> ═══════════
///   sleep stages (hypnogram)
///   breakdown
///   overnight vitals
///   sleep health · 4-dim
///   ══ Patterns ════════════════
///   sleep performance
///   sleep debt · last 7 nights   ── ≥ 2 measured nights
///   last 7 nights                ── ≥ 2 nights
///   bedtime · wake-time          ── ≥ 2 nights with both ends
///   trends · 14 nights
///   findings                     ── when the payload carries any
///   naps · 30 days               ── when there are naps
/// ```
///
/// The conditions are legacy's own, to the comparison. So is every gap: 14 under
/// Tonight and the banner, 10 between cards in a group, 24 before a section
/// heading, and none after one (a `SectionHeading` carries its own 12).
library;

import 'package:flutter/widgets.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_history.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/features/sleep/widgets/breakdown_card.dart';
import 'package:healthee/features/sleep/widgets/hypnogram_card.dart';
import 'package:healthee/features/sleep/widgets/naps_card.dart';
import 'package:healthee/features/sleep/widgets/overnight_vitals_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_consistency_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_debt_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_health_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_hero_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_insight_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_page_head.dart';
import 'package:healthee/features/sleep/widgets/sleep_performance_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_trends_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_week_card.dart';
import 'package:healthee/features/sleep/widgets/stale_sleep_banner.dart';
import 'package:healthee/features/sleep/widgets/tonight_card.dart';
import 'package:healthee/shared/findings_section.dart';
import 'package:healthee/shared/section_heading.dart';

/// Draws one section at the reveal's [progress].
typedef SleepSectionBuilder = Widget Function(BuildContext context, double progress);

/// One entry of the Sleep list: what to draw, its reveal id, and the gap under it.
@immutable
class SleepSection {
  /// Builds an entry.
  const SleepSection(this.id, this.build, {this.gap = 10});

  /// Stable across reorderings, so a card that moves does not re-animate and two
  /// cards cannot share a reveal (`shared/reveal_once.dart`).
  final String id;

  /// What to draw.
  final SleepSectionBuilder build;

  /// Legacy's `SizedBox` under this entry.
  final double gap;
}

/// Every window the screen slices out of the payload, computed once.
///
/// Legacy computed these inline at the top of `build`, which is why the same
/// `nights.take(7).toList().reversed` appears three times there. They are named
/// here so each card takes exactly the window it draws, and so the tests can
/// assert the windows without pumping a widget.
@immutable
class SleepWindows {
  /// Slices [page] against [now].
  factory SleepWindows(SleepPage page, DateTime now) {
    final nights = page.nights;
    final latest = nights.first;
    // Legacy: `nights.take(7).toList().reversed`, filtered to the nights that
    // HAVE a total. A night with no measurement is not a night of no sleep.
    final debt = <DebtNight>[
      for (final night in nights.take(7).toList().reversed)
        if (night.tstMin.valueOrNull case final double minutes)
          (totalMin: minutes, label: weekdayInitials(night.date)),
    ];
    final bedtime = <double>[];
    final wake = <double>[];
    for (final night in nights.take(29).toList().reversed) {
      final start = night.start;
      final end = night.end;
      if (start != null && end != null) {
        bedtime.add(hoursFrom6pm(start));
        wake.add(hoursFrom6pm(end));
      }
    }
    return SleepWindows._(
      latest: latest,
      previous: nights.length > 1 ? nights[1] : null,
      recent: nights.take(14).toList(),
      week: <SleepNightSummary>[
        for (final night in nights.take(7).toList().reversed)
          SleepNightSummary(
            date: night.date,
            durationMin: night.tstMin.valueOrNull?.round() ?? night.stages.total.round(),
            deepMin: night.stages.deep.round(),
            lightMin: night.stages.light.round(),
            remMin: night.stages.rem.round(),
            awakeMin: night.stages.awake.round(),
            deviceScore: night.deviceScore.valueOrNull?.round(),
          ),
      ],
      debt: debt,
      bedtime: bedtime,
      wake: wake,
      label: nightLabel(latest.end, now),
      stale: noSleepLastNight(latest.end, now),
    );
  }

  const SleepWindows._({
    required this.latest,
    required this.previous,
    required this.recent,
    required this.week,
    required this.debt,
    required this.bedtime,
    required this.wake,
    required this.label,
    required this.stale,
  });

  /// The most recent night.
  final SleepNight latest;

  /// The one before it, for the hero's delta badge.
  final SleepNight? previous;

  /// The last fourteen nights, newest first.
  final List<SleepNight> recent;

  /// The last seven nights, oldest first, as the stacked chart's model.
  final List<SleepNightSummary> week;

  /// The measured nights of the last seven, oldest first.
  final List<DebtNight> debt;

  /// Bedtimes on the 18:00 scale, oldest first.
  final List<double> bedtime;

  /// Wake times on the same scale.
  final List<double> wake;

  /// `Last night` · `3 nights ago` — the caption on the header and the heading.
  final String label;

  /// Whether the latest session ended more than a day ago.
  final bool stale;

  /// The fortnight's mean total, or null when nothing in it was measured.
  double? get averageTstMin {
    final measured = <double>[
      for (final night in recent)
        if (night.tstMin.valueOrNull case final double minutes) minutes,
    ];
    return measured.isEmpty
        ? null
        : measured.reduce((a, b) => a + b) / measured.length;
  }

  /// Two is legacy's floor for every conditional chart on this screen.
  static const int minimumNights = 2;
}

/// Builds the ordered section list for one render of Sleep.
List<SleepSection> sleepSections({
  required SleepPage page,
  required SleepConsistency? consistency,
  required DateTime now,
}) {
  final windows = SleepWindows(page, now);
  final night = windows.latest;
  final average = windows.averageTstMin;
  return <SleepSection>[
    SleepSection(
      'head',
      (context, _) => SleepPageHead(
        label: windows.label,
        start: night.start,
        end: night.end,
      ),
      gap: 0,
    ),
    if (consistency?.tonight case final TonightLever lever)
      SleepSection(
        'tonight',
        (context, progress) => TonightCard(lever: lever, progress: progress),
        gap: 14,
      ),
    if (windows.stale)
      SleepSection(
        'stale',
        (context, _) => StaleSleepBanner(windows.label),
        gap: 14,
      ),
    SleepSection('insight', (context, _) => const SleepInsightCard()),
    SleepSection(
      'hero',
      (context, progress) => SleepHeroCard(
        night: night,
        previous: windows.previous,
        progress: progress,
      ),
      gap: 24,
    ),
    SleepSection(
      'last-night-heading',
      (context, _) => SectionHeading(windows.label),
      gap: 0,
    ),
    SleepSection(
      'hypnogram',
      (context, progress) => HypnogramCard(night: night, progress: progress),
    ),
    SleepSection('breakdown', (context, _) => BreakdownCard(night: night)),
    SleepSection('vitals', (context, _) => OvernightVitalsCard(night: night)),
    SleepSection(
      'health',
      (context, _) => SleepHealthCard(
        night: night,
        cutoffs: page.cutoffs,
        notes: page.researchNotes,
      ),
      gap: 24,
    ),
    const SleepSection(
      'patterns-heading',
      _patternsHeading,
      gap: 0,
    ),
    SleepSection(
      'performance',
      (context, progress) => SleepPerformanceCard(
        night: night,
        recent: windows.recent,
        progress: progress,
      ),
    ),
    if (windows.debt.length >= SleepWindows.minimumNights)
      SleepSection(
        'debt',
        (context, progress) =>
            SleepDebtCard(nights: windows.debt, progress: progress),
      ),
    if (windows.week.length >= SleepWindows.minimumNights)
      SleepSection(
        'week',
        (context, progress) => SleepWeekCard(
          nights: windows.week,
          averageLabel: average == null ? null : hoursMinutes(average.round()),
          progress: progress,
        ),
      ),
    if (windows.bedtime.length >= SleepWindows.minimumNights)
      SleepSection(
        'consistency',
        (context, progress) => SleepConsistencyCard(
          bedtime: windows.bedtime,
          wake: windows.wake,
          consistency: consistency,
          progress: progress,
        ),
      ),
    SleepSection(
      'trends',
      (context, progress) =>
          SleepTrendsCard(recent: windows.recent, progress: progress),
    ),
    // `/api/sleep`'s own `findings` — sleep-scoped correlations from this
    // owner's history, which reached no screen at all: the model was not parsed
    // and `FindingsSection` was wired only to `/api/today`'s `top_findings`.
    //
    // Under Patterns, because that is what they are, and **only when the list is
    // non-empty**. `read/findings.py` returns `[]` whenever the analytics layer
    // has nothing, which is most owners most of the time; a heading over an
    // empty list would be a section that exists to say there is nothing in it.
    if (page.findings.isNotEmpty)
      SleepSection(
        'findings',
        (context, _) => FindingsSection(findings: page.findings),
      ),
    if (page.naps.isNotEmpty)
      SleepSection('naps', (context, _) => NapsCard(naps: page.naps), gap: 0),
  ];
}

Widget _patternsHeading(BuildContext context, double progress) =>
    const SectionHeading('Patterns');
