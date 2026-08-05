/// Activity — what the owner did today, what it cost, and what it adds up to.
///
/// **This is where Today's activity and fitness halves went.** Today's Steps and
/// Energy cells open it, and each of those cells is allowed to draw a bare hole
/// where its number would be *because* the card here carries the reason and the
/// remedy in full (`grid_module.dart` strikes that bargain; this screen holds the
/// other half).
///
/// ## Why fitness sits under activity rather than on a tab of its own
///
/// `docs/APP_DESIGN_BRIEF.md` §4.3 puts VO₂max, ACWR and MVPA on one screen and
/// §4.4 gives biological age its own. Biological age is here instead, for a
/// reason the brief itself supplies: its largest term is the fitness term, and
/// that term is the VO₂max estimate on this screen with its instrument named.
/// Two screens, one of which exists to restate the other's headline number, is
/// how two numbers start disagreeing. When the waterfall of §5.7 is built it can
/// have its own route; the card as it stands belongs beside its input.
///
/// The cards are the ones Today used, unchanged. This pass moved them; it did not
/// redesign them.
library;

import 'package:flutter/widgets.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/activity/widgets/biological_age_card.dart';
import 'package:healthee/features/activity/widgets/cardio_load_card.dart';
import 'package:healthee/features/activity/widgets/mvpa_card.dart';
import 'package:healthee/features/activity/widgets/steps_card.dart';
import 'package:healthee/features/activity/widgets/vo2max_card.dart';
import 'package:healthee/features/activity/widgets/workouts_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_head.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_heading.dart';
import 'package:healthee/shared/states/reading_view.dart';

/// The Activity tab.
class ActivityScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const ActivityScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return InstrumentScreen(now: now, sections: activitySections);
  }
}

/// Builds the ordered section list for one render of Activity.
List<PageSection> activitySections(ScreenData data) {
  final snapshot = data.snapshot;
  final reveals = data.reveals;
  return <PageSection>[
    const PageSection(
      PageHead(eyebrow: 'Today', title: 'Activity'),
      gap: PageSpacing.section,
    ),
    if (data.serverFailure case final PageSection failure) failure,
    if (data.serverPending case final PageSection pending) pending,

    PageSection(StepsCard(day: data.day, now: data.now)),
    if (snapshot != null)
      PageSection(
        ReadingView<CardioLoad>(
          reading: snapshot.cardioLoad,
          label: 'Cardio load',
          builder: (context, load) => CardioLoadCard(load: load, reveals: reveals),
        ),
      ),
    if (snapshot != null)
      PageSection(
        ReadingView<Mvpa>(
          reading: snapshot.mvpa,
          label: 'Active minutes',
          builder: (context, mvpa) => MvpaCard(mvpa: mvpa, reveals: reveals),
        ),
      ),
    PageSection(
      WorkoutsCard(workouts: data.day.workouts),
      gap: PageSpacing.section,
    ),

    const PageSection(
      SectionHeading(
        'Fitness',
        subtitle: 'The slow numbers — they move over months, not days',
        // VO₂max and biological age are one family, and it is the same one the
        // cards above wear: `metric_hues.dart` puts the fitness numbers with the
        // movement they are read from.
        metric: 'vo2max_estimate',
      ),
    ),
    if (snapshot != null)
      PageSection(
        ReadingView<Vo2max>(
          reading: snapshot.vo2max,
          label: 'VO₂max',
          builder: (context, vo2max) => Vo2maxCard(vo2max: vo2max, reveals: reveals),
        ),
      ),
    if (snapshot != null)
      PageSection(
        ReadingView<BiologicalAge>(
          reading: snapshot.biologicalAge,
          label: 'Biological age',
          builder: (context, age) => BiologicalAgeCard(age: age),
        ),
      ),
  ];
}
