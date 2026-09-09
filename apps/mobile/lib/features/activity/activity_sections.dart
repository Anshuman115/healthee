/// The ordered sections of Activity. Composition only — no widget is defined here.
///
/// **This is the v02 prototype's screen, in the prototype's order.**
/// `design/mobile-preview/screens-overview.js::H.screens.activity`, read top to
/// bottom:
///
/// ```text
///   header                    date · Activity · avatar
///   today’s movement          steps, the week of them, energy, active minutes
///   context bridge            movement → the longer view, and → recovery
///   your week, by intensity   moderate-equivalent minutes and their parts
///   training load             today's TRIMP against the habit behind it
///   the sessions behind it    the recorded workouts, and the saved routes
///   record an outdoor workout the one filled action on the screen
///   fitness with its source   VO₂max, its rail, its instrument
///   context bridge            the fitness term of the age model
///   activity analysis         this app's own — the prototype has no surface
///   footer
/// ```
///
/// ## What survived the redesign, and what did not
///
/// The **data wiring** survived whole. Every figure is still a [Reading], every
/// block is still gated on what the payload carried, and a refusal still renders
/// as a refusal with the server's own reason.
///
/// The six pre-v02 cards did not. `steps_card`, `workouts_card`, `mvpa_card`,
/// `cardio_load_card`, `vo2max_card` and `biological_age_card` were this
/// screen's only callers, and four of them still drew a `CitationRow` on their
/// face — the surface the owner asked us to move behind the ⓘ. Their sources are
/// not dropped: each v02 panel carries them in `MetricDetail`, which is what
/// makes the ⓘ draw at all.
///
/// **Biological age is not on this screen any more.** The prototype puts it in
/// Today's hero and links to an age-detail screen from here; Today's hero is
/// built, so the number is reachable and is drawn once. Two screens, one of
/// which exists to restate the other's headline number, is how two numbers start
/// disagreeing.
///
/// ## The one section the prototype has no equivalent for
///
/// `InsightCard(scope: 'activity')` is a grounded, server-written reading of
/// this screen's own numbers. The prototype has no surface for it, and Today
/// keeps `ActionsSection` and `InsightsSection` for exactly the same reason:
/// deleting a reachable server surface because the design mock-up has no box for
/// it is a feature removal wearing a redesign's clothes. It sits last, after the
/// bridge, and renders nothing when the server has nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/device/device_workout.dart';
import 'package:healthee/data/history/dated_history.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/activity/v02/movement_panels.dart';
import 'package:healthee/features/activity/v02/training_panels.dart';
import 'package:healthee/shared/format/time_labels.dart';
import 'package:healthee/shared/insight_card.dart';
import 'package:healthee/shared/instrument_screen.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/section_list.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/v02/context_bridge.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/dated_history.dart';
import 'package:healthee/shared/v02/full_button.dart';
import 'package:healthee/shared/v02/list_rows.dart';
import 'package:healthee/shared/v02/page_header.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/withheld_panel.dart';
import 'package:solar_icons/solar_icons.dart';

/// `H.bridge('movement', …)` — what today's movement does and does not move.
const String kActivityRecoveryBridge =
    'Daily movement supports the longer view of fitness. Recent training effort '
    'also belongs in your recovery picture.';

/// `H.bridge('fitness', …)` — the fitness term, named as a model output.
///
/// The years come from the payload's own `contributions` entry. There is no
/// fallback sentence: a bridge that names a contribution the server did not send
/// would be inventing the one number it exists to carry.
String ageBridge(double years) =>
    'The fitness component contributes ${_signed(years)} years to the age '
    'model. That is a model output, not a change in actual age.';

String _signed(double years) =>
    years < 0 ? '−${(-years).toStringAsFixed(1)}' : '+${years.toStringAsFixed(1)}';

/// Everything Activity needs that is not on [ScreenData].
@immutable
class ActivityExtras {
  /// The five places this screen can go. Any of them null draws the control
  /// without its action rather than a control that leads nowhere.
  const ActivityExtras({
    this.onOpenProfile,
    this.onOpenWorkouts,
    this.onOpenWorkout,
    this.onOpenRoutes,
    this.onRecord,
    this.onOpenMetric,
    this.onOpenRecovery,
    this.onOpenFitness,
    this.onOpenBody,
  });

  /// Opens settings. The avatar's destination.
  final VoidCallback? onOpenProfile;

  /// Opens the recorded-workouts list.
  final VoidCallback? onOpenWorkouts;

  /// Opens one recorded session.
  final void Function(DeviceWorkout workout)? onOpenWorkout;

  /// Opens the saved routes.
  final VoidCallback? onOpenRoutes;

  /// Opens the GPS recording flow.
  final VoidCallback? onRecord;

  /// Opens one metric's own history. The panels' `Details` action.
  final void Function(String metric)? onOpenMetric;

  /// Opens the recovery detail — `H.bridge('movement', …, 'recovery', …)`.
  final VoidCallback? onOpenRecovery;

  /// Opens the fitness detail — the VO₂max panel's `Details`.
  final VoidCallback? onOpenFitness;

  /// Opens the age calculation — `H.bridge('fitness', …, 'body', …)`.
  final VoidCallback? onOpenBody;
}

/// `history-screens.js::screens.activity` — `panels([…])`, in its order.
///
/// ```js
/// panels(['steps','energy','total-energy','distance','mvpa','moderate',
///         'vigorous','load','vo2'])
/// ```
///
/// Nine, and this server serves a dated daily series for all nine. The list
/// lives at the screen it belongs to rather than in `shared/`: it IS the design
/// of this screen, and a reader looking for what Activity draws should find it
/// in Activity's own file.
const List<HistoryMetric> kActivityDatedMetrics = <HistoryMetric>[
  HistoryMetric.steps,
  HistoryMetric.activeEnergy,
  HistoryMetric.totalEnergy,
  HistoryMetric.distance,
  HistoryMetric.activeMinutes,
  HistoryMetric.moderate,
  HistoryMetric.vigorous,
  HistoryMetric.cardioLoad,
  HistoryMetric.fitness,
];

/// Builds the ordered section list for one render of Activity.
List<PageSection> activitySections(ScreenData data, ActivityExtras extras) {
  // **The payload is drawn on every day now.** `/api/today` takes an optional
  // `day` and answers for it (`docs/AS_OF_DAY.md`), so MVPA, load and VO₂max are
  // that day's own stored rows rather than today's under an older header. The
  // refusal this line used to make was right while the endpoint answered only for
  // the current day; keeping it now would be withholding data we hold.
  final snapshot = data.snapshot;
  // Layout only — `ScreenData.snapshot` is where "may this payload be drawn under
  // this day" is decided, for every screen at once.
  final past = data.view.isPast;
  final reveals = data.reveals;
  final sections = SectionList()
    ..add(
      V02PageHeader(
        title: 'Activity',
        date: past ? data.view.day : (data.snapshot?.date ?? data.day.date),
        status: data.view.status,
        onOpenProfile: extras.onOpenProfile,
      ),
    );
  // The dated panels stay on a past day, and they are not a duplicate of what
  // the payload now draws: they are the CALENDAR view of each metric — one chart
  // per series across the window — where the panels below are that day's figures
  // with their own breakdowns. The refusal notice that used to head them is gone,
  // because there is nothing left for it to refuse.
  if (past) {
    // `screens.activity` on a past day IS this run of panels, in this order.
    // Every one of them is a row `derive` stamped with a calendar day, so they
    // are as true of 24 July as of today — the refusal above is about the
    // week's totals, the sessions and the analysis, none of which is dated.
    if (data.history case final AsyncValue<DatedHistory> history) {
      addDatedPanels(
        sections,
        history: history,
        metrics: kActivityDatedMetrics,
        day: data.view.day,
        reveals: reveals,
        onRetry: data.onRetryHistory,
        onOpenMetric: extras.onOpenMetric,
      );
      sections.gap(PageSpacing.block);
    }
  }
  // The server's own state is reported on every day now. It was suppressed on a
  // past one because a retry offered to re-fetch a request nobody could make;
  // there IS such a request today, so a failed one is a real failure the owner
  // can act on rather than a card about the wrong day.
  if (data.serverFailure case final PageSection failure) {
    sections.addSection(failure);
    sections.gap(PageSpacing.panel);
  }
  if (data.serverPending case final PageSection pending) {
    sections.addSection(pending);
    sections.gap(PageSpacing.panel);
  }
  sections.add(
    MovementPanel(
      day: data.day,
      snapshot: snapshot,
      reveals: reveals,
      onDetails: _metric(extras, 'steps_total'),
    ),
  );
  sections.add(
    ContextBridge.link(
      kActivityRecoveryBridge,
      label: 'View recovery',
      onOpen: extras.onOpenRecovery,
    ),
  );
  if (snapshot != null) {
    sections.gap(PageSpacing.panel);
    sections.add(
      ReadingView<Mvpa>(
        reading: snapshot.mvpa,
        label: 'Active minutes · MVPA',
        caveatCarrier: CaveatCarrier.insideCard,
        withheldBuilder: (context, disclosure) => WithheldPanel(
          disclosure: disclosure,
          label: 'Active minutes · MVPA',
        ),
        builder: (context, mvpa) => IntensityPanel(
          mvpa: mvpa,
          strength: snapshot.strength,
          reveals: reveals,
          onDetails: _metric(extras, 'mvpa_min'),
        ),
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
        builder: (context, load) => TrainingLoadPanel(
          load: load,
          reveals: reveals,
          onDetails: _metric(extras, 'cardio_load'),
        ),
      ),
    );
  }
  _sessions(sections, data, extras);
  if (snapshot != null) {
    sections.gap(PageSpacing.block);
    sections.add(
      ReadingView<Vo2max>(
        reading: snapshot.vo2max,
        label: 'VO₂max · estimate',
        caveatCarrier: CaveatCarrier.insideCard,
        withheldBuilder: (context, disclosure) =>
            WithheldPanel(disclosure: disclosure, label: 'VO₂max · estimate'),
        builder: (context, vo2max) => FitnessSourcePanel(
          vo2max: vo2max,
          reveals: reveals,
          // `H.panel('Fitness with its source', …, 'fitness')` — the panel's
          // Details opens the fitness screen, not the metric's dated series.
          onDetails: extras.onOpenFitness,
        ),
      ),
    );
    if (fitnessContributionYears(snapshot.biologicalAge.valueOrNull)
        case final double y) {
      sections.add(
        ContextBridge.link(
          ageBridge(y),
          label: 'See the calculation',
          onOpen: extras.onOpenBody,
        ),
      );
    }
  }
  if (!past) {
    sections.gap(PageSpacing.block);
    sections.add(
      const InsightCard(scope: 'activity', title: 'Activity analysis'),
    );
  }
  sections.gap(PageSpacing.block);
  sections.add(const DataFooter());
  return sections.build();
}

/// `The sessions behind it` — the recorded workouts, and the saved routes.
///
/// The routes row is drawn whether or not a session was recorded today: it opens
/// a list this app holds independently of the day being read, and a heading with
/// only that under it is still a true list. A day with no sessions simply has no
/// session rows.
void _sessions(
  SectionList sections,
  ScreenData data,
  ActivityExtras extras,
) {
  final workouts = data.day.workouts;
  sections.gap(PageSpacing.block);
  sections.add(
    SectionHead(
      title: 'The sessions behind it',
      actionLabel: extras.onOpenWorkouts == null ? null : 'See all',
      onAction: extras.onOpenWorkouts,
    ),
  );
  sections.add(
    FlushCard(
      rows: <Widget>[
        for (final workout in workouts)
          V02ListRow(
            icon: SolarIconsOutline.running,
            title: workout.sportLabel,
            detail: _sessionDetail(workout),
            tone: Tone.heart,
            onOpen: extras.onOpenWorkout == null
                ? null
                : () => extras.onOpenWorkout!(workout),
          ),
        V02ListRow(
          icon: SolarIconsOutline.mapPoint,
          title: 'Saved routes',
          detail: 'Recorded GPS tracks · elevation and pace',
          tone: Tone.movement,
          onOpen: extras.onOpenRoutes,
        ),
      ],
    ),
  );
  sections.gap(PageSpacing.block);
  sections.add(
    V02FullButton(
      label: 'Record an outdoor workout',
      onPressed: extras.onRecord,
    ),
  );
}

/// `30 min · 135 bpm avg · 412 kcal by the strap’s count`, dropping what the
/// device did not record. The calorie figure is attributed because CLAUDE.md
/// pins free-living energy to the server's model, so a kcal number here must be
/// unmistakably the device's.
String _sessionDetail(DeviceWorkout workout) => <String>[
  durationLabel(workout.duration.inMinutes),
  if (workout.avgHr > 0) '${workout.avgHr} bpm avg',
  if (workout.calories > 0) "${workout.calories} kcal by the strap's count",
].join(' · ');

/// The fitness term of the age model, or null when the payload has none.
///
/// Public because the fitness screen carries the same bridge: two readings of
/// `contributions[]` would be two chances to name a different number under one
/// sentence.
double? fitnessContributionYears(BiologicalAge? age) {
  for (final term in age?.contributions ?? const <AgeContribution>[]) {
    if (term.term == 'fitness' && term.deltaYears != null) {
      return term.deltaYears;
    }
  }
  return null;
}

VoidCallback? _metric(ActivityExtras extras, String metric) =>
    extras.onOpenMetric == null ? null : () => extras.onOpenMetric!(metric);
