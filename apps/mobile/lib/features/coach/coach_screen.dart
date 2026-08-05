/// Coach — what was found in the owner's own data, and what is not built yet.
///
/// **This is where Today's "Insights" section went.** The findings are the app's
/// most personal claim and its narrowest, and they are not a daily read: a
/// correlation over 105 days does not change between Tuesday and Wednesday, so
/// putting it on the home screen spent eight scroll-lines on a number that is the
/// same as yesterday's.
///
/// ## Why they are here rather than on a tab called Insights
///
/// `docs/APP_DESIGN.md` §2 names the fifth tab Insights and `app_tab_bar.dart`
/// draws it as Coach, following the legacy bar this rebuild is matching. The
/// findings belong on whichever of those exists, and the coach is the surface
/// that will *answer questions about them* — "why did my HRV move with my
/// recovery score" is a coach question whose evidence is the finding.
///
/// ## The coach itself is NOT built, and this screen says so
///
/// A screen titled Coach with no coach on it would be the shape of a feature
/// standing in for the feature. `docs/APP_DESIGN_BRIEF.md` §4.5 describes what
/// the surface will be — free-text questions, cited answers, a `grade_floor` and
/// a questions-remaining meter off `/api/entitlement` — and none of it has
/// shipped. The screen states that plainly, in the same voice it uses for a
/// withheld number: here is what is missing, and here is what would bring it.
library;

import 'package:flutter/widgets.dart';
import 'package:healthee/features/coach/widgets/findings_section.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_head.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// The Coach tab.
class CoachScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const CoachScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return InstrumentScreen(tabIndex: 3, now: now, sections: coachSections);
  }
}

/// Builds the ordered section list for one render of Coach.
List<PageSection> coachSections(ScreenData data) {
  final findings = data.snapshot?.findings ?? const [];
  return <PageSection>[
    const PageSection(
      PageHead(eyebrow: 'In your own data', title: 'Coach'),
      gap: PageSpacing.section,
    ),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,

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
      PageSection(FindingsSection(findings: findings), gap: PageSpacing.section),

    const PageSection(
      SectionHeading(
        'Asking your own questions',
        subtitle: 'Not built yet — and this is what it will take',
      ),
    ),
    const PageSection(
      EmptyState(
        message: 'The coach cannot answer questions yet',
        hint:
            'When it can, every answer will cite the research notes it rests on '
            'and state the weakest evidence grade among them, and the questions '
            'left in your month will be on this screen whether or not you are '
            'near the limit. None of that is wired, so there is no box to type '
            'in rather than a box that would fail.',
      ),
    ),
  ];
}
