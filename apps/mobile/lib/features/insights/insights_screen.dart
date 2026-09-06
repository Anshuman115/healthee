/// Insights — where the owner's own history is read back to them.
///
/// This is `docs/APP_DESIGN.md` §2's fourth tab and legacy's (`app/lib/ui/
/// nav.dart`: Today · Sleep · Activity · **Insights** · Actions). It holds the two
/// things that are about the *history* rather than about today: how each tracked
/// metric has been moving, and the correlations the analytics layer found in this
/// one person's data.
///
/// The findings used to be on a tab called Coach. That was wrong twice over — the
/// coach is not a tab in legacy (it is a button on Today, and it is one again),
/// and the findings are not the coach: they are the evidence a coach question
/// would be answered *from*.
///
/// ## The colour rule this screen exists to keep straight
///
/// Two blocks, two different licences for `fav`/`unf`:
///
/// | block | coloured? | why |
/// |---|---|---|
/// | **Trends** | yes, where polarity is known | a metric moving against the owner's own past, with a table that says which way is better (`shared/format/metric_polarity.dart`) |
/// | **Findings** | never | the sign of a rank correlation is a *direction* — together or opposite — and n-of-1 observational data cannot support "good for you" |
///
/// Legacy kept exactly this restraint: `insights_screen.dart:274` tints a finding
/// `blue = together, amber = opposite (neutral, not good/bad)`. A neutral or
/// unknown-polarity trend gets no colour either, which `trends_section.dart`
/// argues is the load-bearing case rather than the leftover one.
///
/// ## Two things that are deliberately NOT here
///
/// **The recovery signal ladder is on Sleep and stays there.** It already renders
/// the server's own `direction` field (`read/recovery.py` emits
/// `favorable|unfavorable|neutral`), and CLAUDE.md allows one definition per
/// metric: computing a second opinion here would be a second definition of the
/// same judgement, free to disagree with the first.
///
/// **There is no "days that stood out" block**, because `/api/today` cannot
/// produce one. `read/today.py:83` sets `payload["anomalies"] = []`
/// unconditionally, with a comment saying the app is expected to read
/// `/api/notable` instead — a separate, premium-gated, LLM-backed endpoint this
/// app does not call. A section fed by `anomalies` would therefore be a heading
/// that can never have anything under it, which is the dead code Standards §1
/// says to delete rather than keep in case.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/insights/notable_event.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/features/insights/widgets/notable_events.dart';
import 'package:healthee/features/insights/widgets/trends_section.dart';
import 'package:healthee/shared/findings_section.dart';
import 'package:healthee/shared/format/metric_polarity.dart';
import 'package:healthee/shared/history_link.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_head.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The Insights tab.
class InsightsScreen extends ConsumerWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const InsightsScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InstrumentScreen(now: now, sections: insightsSections,
      onRefreshed: () => ref.invalidate(notableEventsProvider));
  }
}

/// Builds the ordered section list for one render of Insights.
List<PageSection> insightsSections(ScreenData data) {
  final snapshot = data.snapshot;
  final findings = snapshot?.findings ?? const [];
  final trends = trendsOf(snapshot?.sparklines ?? const {});
  return <PageSection>[
    const PageSection(
      PageHead(eyebrow: 'Your own history', title: 'Insights'),
      gap: PageSpacing.section,
    ),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,
    const PageSection(HistoryLink()),
    const PageSection(NotableEvents()),
    PageSection(
      Builder(
        builder: (context) => ListTile(
          title: const Text('Challenge outcomes'),
          subtitle: const Text(
            'Progress, data coverage and what changed together',
          ),
          onTap: () => unawaited(context.push(Routes.outcomes)),
        ),
      ),
    ),

    // ── trends ───────────────────────────────────────────────────────────────
    const PageSection(
      SectionHeading(
        'Trends',
        subtitle: 'Where each tracked metric has been going',
      ),
    ),
    if (trends.isEmpty)
      const PageSection(
        EmptyState(
          message: 'No trend windows yet',
          hint:
              'A trend needs at least two days of the same metric. The server '
              'sends these windows once it has them; nothing is drawn from a '
              'single reading.',
        ),
        gap: PageSpacing.section,
      )
    else
      PageSection(
        TrendsSection(trends: trends, reveals: data.reveals),
        gap: PageSpacing.section,
      ),

    // ── findings ─────────────────────────────────────────────────────────────
    const PageSection(
      SectionHeading(
        'Patterns',
        subtitle:
            'What moved together in your history — never what caused what',
      ),
    ),
    if (findings.isEmpty)
      const PageSection(
        EmptyState(
          message: 'Nothing found in your own data yet',
          hint:
              'Findings are correlations searched for across your history. They '
              'need several weeks of two metrics recorded on the same days, and '
              'they have to survive a correction for the size of the search.',
        ),
        gap: PageSpacing.section,
      )
    else
      PageSection(
        FindingsSection(findings: findings),
        gap: PageSpacing.section,
      ),
  ];
}

/// The tracked metrics that have a window worth drawing, in [kTrendMetrics]'s
/// order.
///
/// Reads the ONE list in `metric_polarity.dart` rather than keeping a second one
/// here: a metric this screen drew but that table could not judge would be a
/// colourless row nobody chose, and the mismatch would be invisible.
List<MetricTrend> trendsOf(Map<String, List<TrendPoint>> sparklines) {
  return <MetricTrend>[
    for (final metric in kTrendMetrics)
      if (MetricTrend.from(metric, sparklines[metric] ?? const [])
          case final MetricTrend trend)
        trend,
  ];
}
