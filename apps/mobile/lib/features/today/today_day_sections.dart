/// The last two chapters: `Movement → recovery` and `Patterns → small changes`.
///
/// Split from `today_body.dart` at the 400-line gate (Standards §1). The order
/// across the seam is unbroken; `test/features/today_order_test.dart` reads the
/// whole list.
///
/// ## The two content blocks that kept their pre-v02 widgets
///
/// `ActionsSection` and `InsightsSection` are lists of **server prose with
/// citations attached** — grounded markdown, evidence grades, personal-finding
/// framing. The prototype has no equivalent: it shows two relationship cards
/// that link away to screens where such content lives. Rebuilding those two in
/// v02 chrome would mean rebuilding the citation surface with them, which is a
/// different piece of work from this screen's geometry and is where a
/// `[personal_finding:…]` marker would most easily start leaking again.
///
/// So they keep their carriers and gain the prototype's section heading and its
/// two entry cards around them. Both still render **nothing at all** when the
/// payload carried nothing — a heading over an empty list is the dead code this
/// screen's docstring already refuses for `pai` and for the Today payload's
/// `anomalies`.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/strength.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/today/today_facts.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/v02/day_panels.dart';
import 'package:healthee/features/today/v02/effort_panels.dart';
import 'package:healthee/features/today/v02/longer_panels.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/features/today/widgets/actions_section.dart';
import 'package:healthee/features/today/widgets/insights_section.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/v02/chapter.dart';
import 'package:healthee/shared/v02/context_bridge.dart';
import 'package:healthee/shared/v02/entry_card.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/withheld_panel.dart';
import 'package:solar_icons/solar_icons.dart';

/// The bridge under the step chart: what today's effort does and does not move.
const String kMovementBridge =
    'Today’s activity changes what is left of your readiness. The overnight '
    'recovery number does not update to erase that context.';

/// Everything from the `Movement → recovery` heading down.
void todayDaySections(
  SectionList sections,
  TodayFacts facts,
  ScreenData data,
  TodayExtras extras,
) {
  final snapshot = facts.snapshot;
  final reveals = data.reveals;

  sections.add(
    ChapterHeading(
      key: extras.chapters?.day,
      title: 'Movement → recovery',
      icon: SolarIconsOutline.walking,
      tone: Tone.movement,
    ),
  );
  if (HeartStressPanel.hasSomethingToDraw(
    snapshot.hourlyHeartRate,
    snapshot.hourlyStress,
  )) {
    sections.add(
      // **No Details link, and it is the one panel on this screen without
      // one.** The prototype points it at `metric/hr`; `history_metric.dart`
      // has no daily heart-rate or stress series, so there is nothing to open.
      // A link to a neighbouring metric would be a different measurement
      // behind the same word, and a dead control is worse than none.
      HeartStressPanel(
        heartRate: snapshot.hourlyHeartRate,
        stress: snapshot.hourlyStress,
        reveals: reveals,
      ),
    );
    sections.gap(PageSpacing.panel);
  }
  sections.add(
    StepsEnergyPanel(
      facts: facts,
      reveals: reveals,
      onDetails: extras.onOpenActivity,
    ),
  );
  sections.gap(PageSpacing.block);
  sections.add(
    // `H.bridge('movement', …, 'recovery', 'See the relationship')`.
    ContextBridge.link(
      kMovementBridge,
      label: 'See the relationship',
      onOpen: extras.onOpenRecovery,
    ),
  );
  sections.gap(PageSpacing.panel);
  sections.add(
    ReadingView<CardioLoad>(
      reading: snapshot.cardioLoad,
      label: 'Strain · cardio load',
      caveatCarrier: CaveatCarrier.insideCard,
      withheldBuilder: (context, disclosure) =>
          WithheldPanel(disclosure: disclosure, label: 'Strain · cardio load'),
      builder: (context, load) => EffortPanel(
        load: load,
        reveals: reveals,
        onDetails: _dayMetric(extras, 'cardio_load'),
      ),
    ),
  );
  sections.gap(PageSpacing.panel);
  _targets(sections, facts, extras);
  _longerChapter(sections, facts, reveals, extras);
}

/// One panel's Details link, or none. The twin of `today_body.dart::_metric`,
/// separate only because the two files may not import each other's privates.
VoidCallback? _dayMetric(TodayExtras extras, String metric) {
  final void Function(String metric)? open = extras.onOpenMetric;
  return open == null ? null : () => open(metric);
}

/// Active minutes beside strength, or active minutes alone.
///
/// The strength block is absent on a payload that has none, and a twin row with
/// one live half is a half-width panel next to a hole. So the pair collapses to
/// a single full-width panel rather than drawing a gap where a card would be.
void _targets(SectionList sections, TodayFacts facts, TodayExtras extras) {
  final strength = facts.snapshot.strength;
  // The `ReadingView` wraps the LEFT PANEL ONLY, and that is load-bearing: a
  // `CaveatScope` handed to a `TwinPanels` would be read by both halves, and
  // the MVPA block's disclosure would print a second time under a strength
  // figure it says nothing about. A caveat on the wrong number is a new false
  // claim (`states/caveat_scope.dart`).
  final minutes = ReadingView<Mvpa>(
    reading: facts.snapshot.mvpa,
    label: 'Active minutes · MVPA',
    caveatCarrier: CaveatCarrier.insideCard,
    withheldBuilder: (context, disclosure) =>
        WithheldPanel(disclosure: disclosure, label: 'Active minutes · MVPA'),
    builder: (context, mvpa) =>
        ActiveMinutesPanel(mvpa: mvpa, onDetails: extras.onOpenActivity),
  );
  sections.add(
    strength is Strength
        ? TwinPanels(
            left: minutes,
            right: StrengthPanel(
              strength: strength,
              onDetails: extras.onOpenWorkouts,
            ),
          )
        : minutes,
  );
}

/// `Patterns → small changes` — fitness, the journal, and the two ways out.
void _longerChapter(
  SectionList sections,
  TodayFacts facts,
  RevealRegistry reveals,
  TodayExtras extras,
) {
  final snapshot = facts.snapshot;
  sections.add(
    ChapterHeading(
      key: extras.chapters?.longer,
      title: 'Patterns → small changes',
      icon: SolarIconsOutline.chartSquare,
      tone: Tone.fitness,
    ),
  );
  sections.add(
    ReadingView<Vo2max>(
      reading: snapshot.vo2max,
      label: 'VO₂max · estimate',
      caveatCarrier: CaveatCarrier.insideCard,
      withheldBuilder: (context, disclosure) =>
          WithheldPanel(disclosure: disclosure, label: 'VO₂max · estimate'),
      builder: (context, vo2max) => FitnessPanel(
        vo2max: vo2max,
        reveals: reveals,
        onDetails: extras.onOpenFitness,
      ),
    ),
  );
  // A day with nothing logged draws nothing at all.
  if (!snapshot.routine.isEmpty) {
    sections.gap(PageSpacing.panel);
    sections.add(
      JournalPanel(routine: snapshot.routine, onAdd: extras.onAddLog),
    );
  }
  if (snapshot.recommendations.isNotEmpty || snapshot.action != null) {
    sections.gap(PageSpacing.block);
    sections.add(
      ActionsSection(
        recommendations: snapshot.recommendations,
        // `/api/today.action` — a model-written line nothing else renders.
        action: snapshot.action,
        // The day the payload answers for, so the block can say when the
        // actions it is drawing were written for a different one — the server
        // reaches back two days for the newest set (A3).
        viewedDay: snapshot.asOf?.day,
      ),
    );
  }
  if (snapshot.findings.isNotEmpty) {
    sections.gap(PageSpacing.block);
    sections.add(const SectionHead(title: 'Your patterns'));
    sections.add(InsightsSection(findings: snapshot.findings));
  }
  sections.gap(PageSpacing.block);
  sections.add(
    EntryGrid(
      left: EntryCard(
        title: 'Ask your coach',
        icon: SolarIconsOutline.chatRoundDots,
        body: 'Follow the evidence and your own data, with the uncertainty '
            'kept in view.',
        actionLabel: 'Open the coach',
        onOpen: extras.onOpenCoach,
        tone: Tone.fitness,
      ),
      right: EntryCard(
        title: 'Your next step',
        icon: SolarIconsOutline.flag,
        body: 'Turn context into a small, measurable change.',
        actionLabel: 'Open your actions',
        onOpen: extras.onOpenActions,
        tone: Tone.movement,
      ),
    ),
  );
  sections.gap(PageSpacing.block);
  sections.add(const DataFooter());
}
