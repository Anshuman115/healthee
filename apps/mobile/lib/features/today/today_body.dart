/// Today's body: the hero, the tiles, and the `Last night → today` chapter.
///
/// Split from `today_sections.dart` at the 400-line gate (Standards §1), and the
/// seam is the same one as before the redesign: that file owns the **head** —
/// the things true before any number is read — and this one owns the
/// instruments. `today_day_sections.dart` carries the two chapters after this
/// one, for the same reason.
///
/// The ORDER across all three files is unbroken and
/// `test/features/today_order_test.dart` asserts it against the prototype rather
/// than against any one file.
///
/// ## Every gate here is a gate on what the payload carried
///
/// A block with no data draws **nothing** — no empty panel, no zero-state
/// heading. A block the server *refused* draws a refusal with its reason, which
/// is a different thing and is the whole point of `Reading`. The two are not
/// interchangeable: "there is no sleep history" and "we will not show you the
/// sleep history" are different sentences, and only one of them is about the
/// owner.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/sleep_debt.dart';
import 'package:healthee/data/models/sleep_health.dart';
import 'package:healthee/features/today/today_day_sections.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/v02/mini_trend_panel.dart';
import 'package:healthee/features/today/v02/night_panels.dart';
import 'package:healthee/features/today/v02/recovery_panel.dart';
import 'package:healthee/features/today/v02/today_chapters.dart';
import 'package:healthee/features/today/v02/today_hero.dart';
import 'package:healthee/features/today/widgets/stale_sleep_banner.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/v02/chapter.dart';
import 'package:healthee/shared/v02/context_bridge.dart';
import 'package:healthee/shared/v02/withheld_panel.dart';

/// The bridge under the hero: what the estimate is, and what it is not.
const String kAgeBridge =
    'This estimate combines fitness and sleep contributions. Recovery describes '
    'a different timescale: how you start today.';

/// The bridge under sleep health: sleep's share of the recovery model.
const String kSleepBridge =
    'Sleep carries the largest single share of the recovery model. The full '
    'night includes its stages, its efficiency and its overnight physiology.';

/// Everything from the hero down.
void todayBody(
  SectionList sections,
  TodayFacts facts,
  ScreenData data,
  TodayExtras extras,
) {
  final snapshot = facts.snapshot;
  final reveals = data.reveals;

  sections.add(
    ReadingView<BiologicalAge>(
      reading: snapshot.biologicalAge,
      label: 'Biological age · estimate',
      caveatCarrier: CaveatCarrier.insideCard,
      withheldBuilder: (context, disclosure) => WithheldPanel(
        disclosure: disclosure,
        label: 'Biological age · estimate',
      ),
      builder: (context, age) => TodayBioHero(age: age, reveals: reveals),
    ),
  );
  sections.add(TodaySummaryTiles(facts: facts));
  sections.gap(PageSpacing.block);
  sections.add(ContextBridge.text(kAgeBridge));
  if (extras.chapters case final TodayChapters chapters) {
    sections.add(TodayChapterNav(chapters: chapters));
  }
  _nightChapter(sections, facts, reveals, extras);
  todayDaySections(sections, facts, data, extras);
}

/// `Last night → today` — recovery, the two overnight trends, and the night.
void _nightChapter(
  SectionList sections,
  TodayFacts facts,
  RevealRegistry reveals,
  TodayExtras extras,
) {
  final snapshot = facts.snapshot;
  sections.add(
    ChapterHeading(
      key: extras.chapters?.night,
      title: 'Last night → today',
      icon: Icons.bedtime_outlined,
      tone: Tone.sleep,
    ),
  );
  if (facts.staleSleep) {
    sections.add(StaleSleepBanner(nightLabel: facts.sleepNight));
    sections.gap(PageSpacing.panel);
  }
  sections.add(
    ReadingView<RecoveryScore>(
      reading: snapshot.recovery,
      label: 'Recovery',
      caveatCarrier: CaveatCarrier.insideCard,
      withheldBuilder: (context, disclosure) =>
          WithheldPanel(disclosure: disclosure, label: 'Recovery'),
      builder: (context, score) => RecoveryPanel(score: score),
    ),
  );
  sections.gap(PageSpacing.panel);
  sections.add(
    TwinPanels(
      left: MiniTrendPanel(
        title: 'Overnight HRV',
        label: 'HRV · overnight',
        infoKey: 'hrv',
        icon: Icons.monitor_heart_outlined,
        tone: Tone.fitness,
        reading: facts.heartRateVariability,
        series: facts.spark(TodayMetricIds.heartRateVariability),
        revealId: 'today.hrv-trend',
        reveals: reveals,
        unit: 'ms',
        note: _baselineNote(
          facts.spark(TodayMetricIds.heartRateVariability).length,
          facts.heartRateVariabilityBaseline,
          'ms',
        ),
      ),
      right: MiniTrendPanel(
        title: 'Resting heart',
        label: 'Resting heart rate',
        infoKey: 'rhr_daily',
        icon: Icons.favorite_outline,
        tone: Tone.heart,
        reading: facts.restingHeartRate,
        series: facts.spark(TodayMetricIds.restingHeartRate),
        revealId: 'today.rhr-trend',
        reveals: reveals,
        unit: 'bpm',
        note: _baselineNote(
          facts.spark(TodayMetricIds.restingHeartRate).length,
          facts.median(TodayMetricIds.restingHeartRate),
          'bpm',
        ),
      ),
    ),
  );
  // One bar is not a week. The prototype draws seven; the payload decides.
  if (snapshot.sleepHistory7d.length >= 2) {
    sections.gap(PageSpacing.panel);
    sections.add(
      SleepWeekPanel(nights: snapshot.sleepHistory7d, reveals: reveals),
    );
  }
  sections.gap(PageSpacing.panel);
  sections.add(
    ReadingView<SleepHealth>(
      reading: snapshot.sleepHealth,
      label: 'Sleep health · 4-dim',
      caveatCarrier: CaveatCarrier.insideCard,
      withheldBuilder: (context, disclosure) =>
          WithheldPanel(disclosure: disclosure, label: 'Sleep health · 4-dim'),
      builder: (context, health) =>
          SleepHealthPanel(health: health, breathing: facts.respiratoryRate),
    ),
  );
  sections.gap(PageSpacing.block);
  sections.add(ContextBridge.text(kSleepBridge));
  sections.gap(PageSpacing.panel);
  sections.add(
    TwinPanels(
      left: MiniTrendPanel(
        title: 'Blood oxygen',
        label: 'Blood oxygen · overnight',
        infoKey: 'spo2',
        icon: Icons.water_drop_outlined,
        tone: Tone.oxygen,
        reading: facts.bloodOxygen,
        series: facts.spark(TodayMetricIds.bloodOxygenMin),
        revealId: 'today.blood-oxygen',
        reveals: reveals,
        unit: '%',
        digits: 1,
        note: 'Nightly minimums. Gaps stay visible.',
      ),
      right: ReadingView<SleepDebt>(
        reading: facts.snapshot.sleepDebt,
        label: 'Sleep need · debt',
        caveatCarrier: CaveatCarrier.insideCard,
        withheldBuilder: (context, disclosure) =>
            WithheldPanel(disclosure: disclosure, label: 'Sleep need · debt'),
        builder: (context, debt) => SleepNeedPanel(debt: debt),
      ),
    ),
  );
}

/// `14 nights · baseline 45 ms`, or the count alone when nothing is baselined.
///
/// **Never a baseline computed here.** `today_facts.dart` records why: a median
/// over the fourteen points on the chart is a baseline over a different window
/// from the one every other surface quotes — a second definition arriving as a
/// helpful-looking last resort. A metric the server has not baselined draws no
/// baseline.
String _baselineNote(int samples, double? baseline, String unit) {
  final nights = '$samples ${samples == 1 ? 'night' : 'nights'}';
  return baseline == null
      ? nights
      : '$nights · baseline ${baseline.round()} $unit';
}
