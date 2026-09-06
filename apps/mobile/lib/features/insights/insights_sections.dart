/// The ordered sections of Insights. Composition only — no widget is defined here.
///
/// **This is the v02 prototype's screen, in the prototype's order.**
/// `design/mobile-preview/screens-overview.js::H.screens.insights`, read top to
/// bottom:
///
/// ```text
///   header                    date · Insights · avatar
///   relationship grid         one pattern of your own, and the age model
///   effort & stress           one hour cursor, two labelled scales
///   context bridge            what a sensor cannot see
///   your longer patterns      the tracked metrics, and `All metrics`
///   what changed together?    the findings, the notable days, the two ways in
///   a useful question comes next
///   footer
/// ```
///
/// ## The colour rule this screen exists to keep straight
///
/// Two blocks, two different licences for `fav`/`unf`:
///
/// | block | coloured? | why |
/// |---|---|---|
/// | **Your longer patterns** | yes, where polarity is known | a metric moving against the owner's own past, with a table that says which way is better (`shared/format/metric_polarity.dart`) |
/// | **What changed together?** | never | the sign of a rank correlation is a *direction* — together or opposite — and n-of-1 observational data cannot support "good for you" |
///
/// A neutral or unknown-polarity trend gets no colour either, which
/// `trends_section.dart` argues is the load-bearing case rather than the
/// leftover one.
///
/// ## What kept its pre-v02 carrier, and why
///
/// `FindingsSection` and `NotableEvents` are lists of **server prose with
/// citations attached** — grounded markdown, the single-subject framing, the
/// statistic behind a disclosure. The prototype has no equivalent: it shows a
/// card that links away to a screen where such content would live. Rebuilding
/// them in v02 chrome would mean rebuilding the citation surface with them,
/// which is a different piece of work and is where a `[personal_finding:…]`
/// marker would most easily start leaking again. Today made exactly this call
/// for `ActionsSection` and `InsightsSection`; these two keep their carriers and
/// gain the prototype's heading around them.
///
/// ## Two things that are deliberately NOT here
///
/// **The recovery signal ladder is on Today and stays there.** It renders the
/// server's own `direction` field, and CLAUDE.md allows one definition per
/// metric: computing a second opinion here would be free to disagree with the
/// first.
///
/// **There is no "days that stood out" block fed by `anomalies`.**
/// `read/today.py:83` sets it to `[]` unconditionally, so a section keyed on it
/// is a heading that can never have anything under it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/insights/v02/pattern_panels.dart';
import 'package:healthee/features/insights/widgets/notable_events.dart';
import 'package:healthee/features/insights/widgets/trends_section.dart';
import 'package:healthee/shared/findings_section.dart';
import 'package:healthee/shared/format/metric_polarity.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/v02/context_bridge.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/entry_card.dart';
import 'package:healthee/shared/v02/list_rows.dart';
import 'package:healthee/shared/v02/page_header.dart';
import 'package:healthee/shared/v02/section_head.dart';

/// Everything Insights needs that is not on [ScreenData].
@immutable
class InsightsExtras {
  /// The five places this screen can go.
  const InsightsExtras({
    this.onOpenProfile,
    this.onOpenMetric,
    this.onOpenHistory,
    this.onOpenOutcomes,
    this.onOpenJournal,
    this.onOpenCoach,
  });

  /// Opens settings. The avatar's destination.
  final VoidCallback? onOpenProfile;

  /// Opens one metric's own history. A trend panel's `Details`.
  final void Function(String metric)? onOpenMetric;

  /// Opens the metric explorer. The section head's `All metrics`.
  final VoidCallback? onOpenHistory;

  /// Opens the challenge outcomes.
  final VoidCallback? onOpenOutcomes;

  /// Opens the journal.
  final VoidCallback? onOpenJournal;

  /// Opens the coach sheet.
  final VoidCallback? onOpenCoach;
}

/// Builds the ordered section list for one render of Insights.
List<PageSection> insightsSections(ScreenData data, InsightsExtras extras) {
  final snapshot = data.snapshot;
  final findings = snapshot?.findings ?? const <Finding>[];
  final trends = trendsOf(snapshot?.sparklines ?? const {});
  final sections = SectionList()
    ..add(
      V02PageHeader(
        title: 'Insights',
        date: snapshot?.date ?? data.day.date,
        onOpenProfile: extras.onOpenProfile,
      ),
    );
  if (data.serverFailure case final PageSection failure) {
    sections.addSection(failure);
    sections.gap(PageSpacing.panel);
  }
  if (data.serverPending case final PageSection pending) {
    sections.addSection(pending);
    sections.gap(PageSpacing.panel);
  }
  _entries(sections, data, findings);
  if (snapshot != null &&
      EffortStressPanel.hasSomethingToDraw(
        snapshot.hourlyHeartRate,
        snapshot.hourlyStress,
      )) {
    sections.add(
      EffortStressPanel(
        heartRate: snapshot.hourlyHeartRate,
        stress: snapshot.hourlyStress,
        reveals: data.reveals,
      ),
    );
    sections.gap(PageSpacing.block);
    sections.add(ContextBridge.text(kJournalBridge));
  }
  // A heading over no panels reads as breakage. The honest state is silence:
  // a trend needs two days of the same metric and the server sends the window
  // once it has one.
  if (trends.isNotEmpty) {
    sections.gap(PageSpacing.block);
    sections.add(
      SectionHead(
        title: 'Your longer patterns',
        actionLabel: extras.onOpenHistory == null ? null : 'All metrics',
        onAction: extras.onOpenHistory,
      ),
    );
    sections.add(
      TrendsGrid(
        trends: trends,
        reveals: data.reveals,
        onOpenMetric: extras.onOpenMetric,
      ),
    );
  }
  _changedTogether(sections, findings, extras);
  sections.gap(PageSpacing.block);
  sections.add(CoachQuestionPanel(onOpenCoach: extras.onOpenCoach));
  sections.gap(PageSpacing.block);
  sections.add(const DataFooter());
  return sections.build();
}

/// `.relationship-grid` — one pattern of the owner's own, and the age model.
///
/// Either card may be absent, so the row is built from what there is: two cards
/// make the grid, one draws full width, none draws nothing. A grid with one live
/// half is a card beside a hole.
void _entries(SectionList sections, ScreenData data, List<Finding> findings) {
  final age = AgeEntryCard.contribution(
    data.snapshot?.biologicalAge.valueOrNull,
  );
  final Finding? pattern = findings
      .where(FindingEntryCard.canDraw)
      .firstOrNull;
  final cards = <Widget>[
    if (pattern != null) FindingEntryCard(finding: pattern),
    if (age != null) AgeEntryCard(years: age),
  ];
  if (cards.isEmpty) {
    return;
  }
  sections.add(
    cards.length == 2
        ? EntryGrid(left: cards.first, right: cards.last)
        : cards.first,
  );
  sections.gap(PageSpacing.panel);
}

/// `What changed together?` — the findings, the notable days, and two ways in.
///
/// The heading is the prototype's and it is also the findings' own framing: what
/// moved together, never what caused what. The two rows are the prototype's
/// (`H.row('flag', …, 'outcomes')` and `H.row('journal', …, 'journal')`), pointed
/// at the screens this app actually has.
void _changedTogether(
  SectionList sections,
  List<Finding> findings,
  InsightsExtras extras,
) {
  sections.gap(PageSpacing.block);
  sections.add(const SectionHead(title: 'What changed together?'));
  if (findings.isNotEmpty) {
    sections.add(FindingsSection(findings: findings));
    sections.gap(PageSpacing.panel);
  }
  sections.add(const NotableEvents());
  sections.gap(PageSpacing.panel);
  sections.add(
    FlushCard(
      rows: <Widget>[
        V02ListRow(
          icon: Icons.flag_outlined,
          title: 'Challenge outcomes',
          detail: 'Progress, data coverage and what changed together',
          tone: Tone.movement,
          onOpen: extras.onOpenOutcomes,
        ),
        V02ListRow(
          icon: Icons.menu_book_outlined,
          title: 'Notable moments',
          detail: 'Your caffeine, meditation and fasting context',
          tone: Tone.stress,
          onOpen: extras.onOpenJournal,
        ),
      ],
    ),
  );
}

/// The tracked metrics that have a window worth drawing, in [kTrendMetrics]'s
/// order.
///
/// Reads the ONE list in `metric_polarity.dart` rather than keeping a second one
/// here: a metric this screen drew but that table could not judge would be a
/// colourless panel nobody chose, and the mismatch would be invisible.
List<MetricTrend> trendsOf(Map<String, List<TrendPoint>> sparklines) {
  return <MetricTrend>[
    for (final metric in kTrendMetrics)
      if (MetricTrend.from(metric, sparklines[metric] ?? const [])
          case final MetricTrend trend)
        trend,
  ];
}
