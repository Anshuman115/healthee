/// The two workout surfaces, in the prototype's order — asserted on what was
/// rendered, not on a list literal.
///
/// A section that landed below the fold is still in the widget tree, so a test
/// that walked `workoutDetailSections` would pass on a screen whose sections
/// were drawn in any order at all. These read the strings the screens actually
/// produced, in tree order, and check each one comes after the last.
///
/// The order itself is `design/mobile-preview/screens-explore.js`:
/// `H.screens.workouts` and `H.screens.workout`, read top to bottom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/features/workouts/v02/effort_cards.dart';
import 'package:healthee/features/workouts/v02/session_cards.dart';
import 'package:healthee/features/workouts/v02/session_rows.dart';
import 'package:healthee/features/workouts/workout_detail_screen.dart';
import 'package:healthee/features/workouts/workout_detail_sections.dart';
import 'package:healthee/features/workouts/workout_history_screen.dart';
import 'package:healthee/shared/v02/data_footer.dart';

import '../_today_stubs.dart';
import '../history/_history_host.dart' show indexOfText, textsOn, useRealFonts;
import '_workouts_host.dart';

/// Tall enough that a `ListView`'s lazy build reaches the footer.
const double kTallViewport = 5000;

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  double width = 390,
  bool withToday = false,
}) async {
  tester.view
    ..physicalSize = Size(width, kTallViewport)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    workoutsHost(home, width: width, view: withToday ? todayView() : null),
  );
  await tester.pumpAndSettle();
}

void _inOrder(List<String> texts, List<String> order) {
  var previous = -1;
  for (final line in order) {
    final at = indexOfText(texts, line);
    expect(at, greaterThan(previous), reason: '"$line" is out of order');
    previous = at;
  }
}

void main() {
  useRealFonts();

  group('the session list is H.screens.workouts', () {
    testWidgets('BUTTON · BOUNDS · DAY · SESSIONS · STRENGTH · FOOTER', (
      tester,
    ) async {
      await _pump(tester, const WorkoutHistoryScreen(), withToday: true);

      _inOrder(textsOn(tester), <String>[
        'Your workouts.', // the detail head's h1
        kRecordLabel, // H.link('Record a workout', …, 'button full')
        'The latest 100 uploaded sessions', // what the list leaves out
        'JUL 31', // <p class="tiny-label">
        'Outdoor run', // the .workout-row row
        StrengthCard.title, // H.section('Weekly strength')
        'Recorded strength activity',
        kStrengthSeparate,
        kHowWeKnow, // H.evidence('strength_training_mortality')
        DataFooter.line, // H.footer()
      ]);
    });

    testWidgets('the row says duration, distance and the average heart rate', (
      tester,
    ) async {
      await _pump(tester, const WorkoutHistoryScreen());
      // `H.row('walk','Morning run','30 min · 4.2 km · 135 bpm avg','workout')`
      // in the app's own duration vocabulary — `durationLabel`, not a third one.
      expect(find.text('30m · 4.2 km · 135 bpm avg'), findsOneWidget);
    });

    testWidgets('a day with sessions draws no empty notice', (tester) async {
      await _pump(tester, const WorkoutHistoryScreen(), withToday: true);
      expect(find.text(kNoSessionsTitle), findsNothing);
    });

    testWidgets('no sessions is a notice, and the strength card survives it', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, kTallViewport)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        workoutsHost(
          const WorkoutHistoryScreen(),
          sessions: const [],
          view: todayView(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(kNoSessionsTitle), findsOneWidget);
      expect(find.text(kNoSessionsBody), findsOneWidget);
      expect(find.text(StrengthCard.title), findsOneWidget);
    });

    testWidgets('an unreachable Today draws no strength card at all', (
      tester,
    ) async {
      await _pump(tester, const WorkoutHistoryScreen());
      // Not an error card either: the Today payload's failure belongs to the
      // screens that are about it, and this list merely borrows one block.
      expect(find.text(StrengthCard.title), findsNothing);
      expect(find.text('Outdoor run'), findsOneWidget);
    });
  });

  group('the workout screen is H.screens.workout', () {
    testWidgets('SUMMARY · EFFORT · ZONES · DETAILS · COACH · FOOTER', (
      tester,
    ) async {
      await _pump(tester, const WorkoutDetailScreen(start: kWorkoutStart));

      _inOrder(textsOn(tester), <String>[
        '31 Jul · 07:00', // .page-header .date, above the title
        'Outdoor run.', // the detail head's h1
        'Distance', // .three
        'Duration',
        'Avg. pace',
        kWorkoutSource, // H.source(…)
        EffortCard.title, // H.section('Your effort through the run')
        'Average heart rate',
        'Peak 168 bpm', // H.badge('Peak 168 bpm')
        kTraceNote, // <p class="small">
        ZonesCard.title, // H.section('Time in heart-rate zones')
        'Zone 1',
        'minutes classified', // <p class="small">
        kZonesEvidenceLabel, // H.evidence('cardio_load_trimp', …)
        SessionDetailsCard.title, // H.section('Session details')
        'Estimated energy', // .two
        'TRIMP load',
        'Average speed',
        'Heart-rate drift',
        kDiscussLabel, // H.link(…, 'button secondary full section')
        'Workout analysis', // this app's own, after the prototype's last control
        DataFooter.line, // H.footer()
      ]);
    });

    testWidgets('the figures are the payload’s, in the prototype’s units', (
      tester,
    ) async {
      await _pump(tester, const WorkoutDetailScreen(start: kWorkoutStart));
      // `StatBlock` draws the figure and its unit as one rich span, so these
      // are the strings a reader actually sees rather than two boxes.
      final said = textsOn(tester);
      for (final figure in <String>[
        '4.2 km',
        '30 min',
        '7:08 /km', // the server's 7.14, as a clock
        '135 bpm',
        '250 kcal',
        '36.9', // TRIMP is unitless
        '8.4 km/h',
        '+10 bpm',
      ]) {
        expect(said, contains(figure));
      }
    });

    testWidgets('the energy figure names the instrument it came from', (
      tester,
    ) async {
      await _pump(tester, const WorkoutDetailScreen(start: kWorkoutStart));
      // CLAUDE.md pins free-living energy to the MET-by-state model, and this
      // number is not it. Unnamed, an owner reads it as the model's.
      expect(find.text(kEnergyInstrument), findsOneWidget);
      expect(find.text(kDriftCaveat), findsOneWidget);
    });
  });
}
