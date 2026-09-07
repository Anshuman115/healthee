/// The ordered sections of Sleep. Composition only — no widget is defined here.
///
/// **This is the v02 prototype's screen, in the prototype's order.**
/// `design/mobile-preview/sleep-history-view.js::H.screens.sleep`, read top to
/// bottom at 390 px with the prototype open in a browser:
///
/// ```text
///   header                     date · Sleep · avatar
///   .sleep-reading             time asleep, and the strap's own score
///   .colour-key                bedtime · wake · time in bed
///   How your night unfolded    the stage timeline and its legend
///   Every stage, accounted for the proportion strip, then the four totals
///   Your body overnight        five overnight measurements, each with a spark
///   Your four sleep checks     four readings, four cutoffs, no total
///   Sleep need & debt          the shortfall, and what it is a shortfall against
///   Your week, stage by stage  seven nights, stacked
///   Sleep timing               bedtime and wake, and the regularity around them
///   ══ Beyond a single night ══
///   Sleep efficiency           the fortnight
///   Sleep regularity           the fortnight
///   Heart-rate variability     the fortnight
///   Naps & your day            the daytime sleep, and the journal
///   Sleep recommendations      the one link out
///   footer
/// ```
///
/// ## What is on this screen that the prototype has no box for
///
/// Four things, and all four sit **after** every panel the prototype draws, so
/// its order is never interrupted:
///
/// - **Tonight** — `/api/sleep/consistency`'s lever.
/// - **Sleep analysis** — `/api/sleep/insight`'s grounded reading.
/// - **Findings** — `/api/sleep`'s own sleep-scoped correlations, drawn only
///   when the list is non-empty; a heading over an empty list is a section that
///   exists to say there is nothing in it.
///
/// The fourth is the **stale banner**, and it is the exception that sits near
/// the top: it says *everything below is from an older night*, and a sentence
/// like that is worth nothing under the thing it qualifies. That is the honesty
/// layer, which is the one place this rebuild has latitude.
///
/// ## What survived the redesign
///
/// The **data wiring**, whole. Three reads that fail independently, every figure
/// still a `Reading`, every refusal still rendered as a refusal with the
/// server's own reason, and the four sleep dimensions still four.
///
/// The eleven pre-v02 cards did not survive. Their measurements did: every one
/// of them is on a panel above, and the references and citations they drew on
/// their faces now open from the ⓘ, which is where the owner asked them to live.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/features/sleep/sleep_windows.dart';
import 'package:healthee/features/sleep/v02/checks_panel.dart';
import 'package:healthee/features/sleep/v02/naps_panel.dart';
import 'package:healthee/features/sleep/v02/need_panel.dart';
import 'package:healthee/features/sleep/v02/night_panels.dart';
import 'package:healthee/features/sleep/v02/sleep_reading.dart';
import 'package:healthee/features/sleep/v02/tail_panels.dart';
import 'package:healthee/features/sleep/v02/timing_panel.dart';
import 'package:healthee/features/sleep/v02/trend_panels.dart';
import 'package:healthee/features/sleep/v02/vitals_panel.dart';
import 'package:healthee/features/sleep/v02/week_panel.dart';
import 'package:healthee/features/sleep/v02/withheld_night.dart';
import 'package:healthee/shared/findings_section.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/chapter.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/page_header.dart';

/// `H.chapter('sleep-trends','Beyond a single night','sleep','insights')`.
const String kSleepTrendsChapter = 'Beyond a single night';

/// Everything Sleep needs that is not on the payloads.
@immutable
class SleepExtras {
  /// The four places this screen can go. Any of them null draws the control
  /// without its action rather than a control that leads nowhere.
  const SleepExtras({
    this.onOpenProfile,
    this.onOpenMetric,
    this.onOpenJournal,
    this.onOpenActions,
  });

  /// Opens settings. The avatar's destination.
  final VoidCallback? onOpenProfile;

  /// Opens one measurement's own history.
  final void Function(String metric)? onOpenMetric;

  /// Opens the journal.
  final VoidCallback? onOpenJournal;

  /// Opens the recommendations.
  final VoidCallback? onOpenActions;
}

/// Builds the ordered section list for one render of Sleep.
List<PageSection> sleepSections({
  required SleepPage page,
  required SleepConsistency? consistency,
  required DateTime now,
  required RevealRegistry reveals,
  SleepExtras extras = const SleepExtras(),
}) {
  final windows = SleepWindows(page, now);
  final night = windows.latest;
  final sections = SectionList()
    ..add(
      V02PageHeader(
        title: 'Sleep',
        date: night.date,
        onOpenProfile: extras.onOpenProfile,
      ),
    );
  if (windows.stale) {
    sections
      ..add(StaleNightNotice(label: windows.label))
      ..gap(PageSpacing.panel);
  }
  sections
    ..add(SleepReading(night: night))
    ..gap(PageSpacing.panel)
    ..add(
      NightTimelinePanel(
        night: night,
        reveals: reveals,
        onDetails: _metric(extras, 'sleep_stages'),
      ),
    )
    ..gap(PageSpacing.panel)
    ..add(StageTablePanel(night: night, reveals: reveals))
    ..gap(PageSpacing.panel)
    ..add(
      OvernightPanel(
        night: night,
        recent: windows.recent,
        reveals: reveals,
        onOpenMetric: extras.onOpenMetric,
      ),
    )
    ..gap(PageSpacing.panel)
    ..add(
      SleepChecksPanel(
        night: night,
        cutoffs: page.cutoffs,
        notes: page.researchNotes,
      ),
    )
    ..gap(PageSpacing.panel)
    ..add(
      SleepNeedPanel(night: night, nights: windows.debt, reveals: reveals),
    );
  if (windows.week.length >= SleepWindows.minimumNights) {
    sections
      ..gap(PageSpacing.panel)
      ..add(
        StageWeekPanel(
          nights: windows.week,
          span: windows.weekSpan,
          reveals: reveals,
          onDetails: _metric(extras, 'sleep_stages'),
        ),
      );
  }
  sections
    ..gap(PageSpacing.panel)
    ..add(
      SleepTimingPanel(
        bedtime: windows.bedtime,
        wake: windows.wake,
        dates: windows.timingDates,
        consistency: consistency,
        reveals: reveals,
      ),
    )
    ..gap(PageSpacing.block)
    ..add(
      const ChapterHeading(
        title: kSleepTrendsChapter,
        icon: Icons.insights_outlined,
      ),
    );
  for (final trend in kSleepTrends) {
    sections
      ..add(
        SleepTrendPanel(
          trend: trend,
          recent: windows.recent,
          reveals: reveals,
          onDetails: extras.onOpenMetric,
        ),
      )
      ..gap(PageSpacing.panel);
  }
  sections
    ..add(
      NapsPanel(naps: page.naps, onOpenJournal: extras.onOpenJournal),
    )
    ..gap(PageSpacing.block)
    ..add(
      HLinkButton(
        label: 'Sleep recommendations',
        onPressed: extras.onOpenActions,
      ),
    )
    ..gap(PageSpacing.block);
  if (consistency?.tonight case final TonightLever lever) {
    sections
      ..add(TonightPanel(lever: lever))
      ..gap(PageSpacing.panel);
  }
  sections.add(const SleepAnalysisPanel());
  // `/api/sleep`'s own sleep-scoped correlations, and only when there are any.
  if (page.findings.isNotEmpty) {
    sections
      ..gap(PageSpacing.block)
      ..add(FindingsSection(findings: page.findings));
  }
  sections
    ..gap(PageSpacing.block)
    ..add(const DataFooter());
  return sections.build();
}

VoidCallback? _metric(SleepExtras extras, String metric) =>
    extras.onOpenMetric == null ? null : () => extras.onOpenMetric!(metric);
