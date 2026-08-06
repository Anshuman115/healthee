/// Actions — every cited action the server raised for today, in full.
///
/// This is the tab `core/tabs.dart` took OUT of the bar, and it is back because
/// it now has a screen. The argument for removing it was right and is worth
/// keeping: a tab is a promise of a destination and there is no wording available
/// inside a 10 pt label to qualify one that does not exist. The answer to that was
/// never a dimmed tab; it was a screen.
///
/// ## What is here that Today does not show
///
/// Today draws the **top** recommendation under "Suggested today" — its heading
/// has always said "One action, and the reading behind it". This screen draws the
/// whole ranked set, and each one names the reading that raised it
/// (`signal_source`), which is the part that does not fit on an index.
///
/// ## Where they come from, and the honest limits
///
/// `/api/today`'s `recommendations[]`, written by the nightly job into the
/// server's `recommendation` table and read back by `read/today.py`. Three facts
/// about that shape the copy here rather than being hidden by it:
///
///   * **It is one day's set, not a history.** `_recommendations_today` returns
///     the latest set of 1–3 rows and falls back up to two days; there is no
///     endpoint for older ones, so this screen does not imply a log.
///   * **The app cannot mark one done.** `adopted` is on the wire and nothing in
///     this app writes it. A checkbox that changed nothing on the server would be
///     a control that lies, so there is none — see the standing rule that a
///     surface may not offer an affordance it cannot honour.
///   * **They need the server.** With no session or no answer the derived half is
///     empty and says so once, through the shared failure card, exactly as every
///     other tab does.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/recommendation.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_head.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/recommendation_entry.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The Actions tab.
class ActionsScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const ActionsScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return InstrumentScreen(now: now, sections: actionsSections);
  }
}

/// Builds the ordered section list for one render of Actions.
List<PageSection> actionsSections(ScreenData data) {
  final snapshot = data.snapshot;
  final recommendations = snapshot?.recommendations ?? const <Recommendation>[];
  return <PageSection>[
    const PageSection(
      PageHead(eyebrow: 'Suggested today', title: 'Actions'),
      gap: PageSpacing.section,
    ),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,

    if (snapshot?.action case final String sentence)
      PageSection(_DailyLine(sentence: sentence)),

    if (recommendations.isEmpty)
      const PageSection(
        EmptyState(
          message: 'Nothing suggested for today',
          hint:
              'Actions are written overnight from the readings the server has, '
              'and only where a reading actually raised one. A quiet day is a '
              'day with nothing worth telling you to change.',
        ),
        gap: PageSpacing.section,
      )
    else ...[
      for (final recommendation in recommendations)
        PageSection(_ActionCard(recommendation: recommendation)),
      const PageSection(_TodayOnlyNote(), gap: PageSpacing.section),
    ],
  ];
}

/// The AI one-liner, when the nightly job has warmed one.
class _DailyLine extends StatelessWidget {
  const _DailyLine({required this.sentence});

  final String sentence;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The day in one line', style: text.labelSmall),
          const SizedBox(height: Insets.sm),
          GroundedProse(text: sentence, style: text.headlineSmall),
        ],
      ),
    );
  }
}

/// One recommendation in its own card, with the reading that raised it.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.recommendation});

  final Recommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return StateCard(
      child: RecommendationEntry(
        recommendation: recommendation,
        showSignal: true,
      ),
    );
  }
}

/// Says what this list is and is not, once, at the bottom.
class _TodayOnlyNote extends StatelessWidget {
  const _TodayOnlyNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Text(
      "This is today's set. The server keeps no history of past actions and "
      'this app cannot mark one as done, so nothing here is a checklist — it is '
      'what your own readings suggested this morning.',
      style: text.bodySmall?.copyWith(color: colors.ink3),
    );
  }
}
