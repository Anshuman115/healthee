/// The biological-age screen: the calculation, and the lever it will not price.
///
/// Three things this suite exists to hold:
///
///   * **The equation is the payload's arithmetic**, not a sentence written into
///     the app. It is drawn from `chronological_age` and `contributions[]`, so a
///     model that reweights a term rewrites the sentence.
///   * **`excluded` is not `withheld`.** The exclusion panel ships the server's
///     paragraph verbatim, offers no retry, and draws on a payload that carried
///     a value as well as on one that did not — the term is not a lever either
///     way. `reading.dart` argues why blurring those two is the one thing a UI
///     must not do here.
///   * **The exclusion is not counted twice.** It arrives merged into the
///     caveats on a valued payload, and the confidence panel takes it back out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/body_screen.dart';
import 'package:healthee/features/today/v02/body_limits_panels.dart';
import 'package:healthee/features/today/v02/body_panels.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/comparison_bars.dart';
import 'package:healthee/shared/v02/instruments/age_waterfall.dart';

import '../_today_stubs.dart';
import '_settings_harness.dart' show tallViewport;
import '_today_host.dart';

/// The first sentence of the server's own exclusion paragraph.
const String _exclusionOpening =
    'Sleep regularity is not one of the levers behind this number.';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() => store.close());

  group('the calculation is the payload’s', () {
    testWidgets('THE EQUATION IS BUILT FROM THE TERMS, NOT WRITTEN OUT', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        todayHost(store, server: todayView(), home: const BodyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AgeWaterfall), findsOneWidget);
      expect(
        find.text(
          '36 chronological years − 1.7 fitness + 0.0 sleep duration '
          '= 34.3 modelled years.',
        ),
        findsOneWidget,
      );
    });

    test('the equation reads the contributions it was given', () {
      final age = BiologicalAge.maybe(
        loadTodayJson()['biological_age']! as Map<String, Object?>,
      )!;
      expect(
        AgeLadderPanel.equation(age, 36),
        contains('− 1.7 fitness'),
      );
      // A term the model stopped sending stops appearing, because the sentence
      // is a fold over the list rather than a template with two slots.
      const bare = BiologicalAge(
        biologicalAge: 34.3,
        chronologicalAge: 36,
        deltaYears: -1.7,
        contributions: <AgeContribution>[],
        disclaimer: null,
        researchNotes: <String>[],
      );
      expect(
        AgeLadderPanel.equation(bare, 36),
        '36 chronological years = 34.3 modelled years.',
      );
    });

    testWidgets('both contribution panels draw their own instrument', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        todayHost(store, server: todayView(), home: const BodyScreen()),
      );
      await tester.pumpAndSettle();

      // The hero's row and the panel below it, for fitness. The sleep row is
      // named `Sleep duration contribution` because that is the term the model
      // sent — the hero prints the payload's own word and the panel prints the
      // prototype's title, and neither invents the other's.
      expect(find.text(FitnessTermPanel.title), findsNWidgets(2));
      expect(find.text('Sleep duration contribution'), findsOneWidget);
      expect(find.text(SleepTermPanel.title), findsOneWidget);
      // The sleep term is read at a value that is NOT the value measured, and
      // the panel has to show both or it is showing a number the model did not
      // use. `compared_as` is 7.0 against a measured 6.3.
      expect(find.textContaining('6.3h wearable average'), findsOneWidget);
      expect(find.textContaining('Compared as 7.0h'), findsWidgets);
    });
  });

  group('excluded is not withheld', () {
    testWidgets('THE SERVER’S EXCLUSION PARAGRAPH SHIPS VERBATIM', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        todayHost(store, server: todayView(), home: const BodyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text(ExcludedTermsPanel.title), findsOneWidget);
      expect(find.textContaining(_exclusionOpening), findsOneWidget);
      // No retry. The owner can do nothing about this one and must not be
      // invited to try.
      expect(find.widgetWithText(FilledButton, 'Try again'), findsNothing);
    });

    testWidgets('a WITHHELD estimate still names what is excluded', (
      tester,
    ) async {
      tallViewport(tester);
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'biological_age': <String, Object?>{
                ...json['biological_age']! as Map<String, Object?>,
                'biological_age': null,
                'withheld': <String, Object?>{
                  'reason': 'logged_weight_stale',
                  'message': 'Log a weigh-in and this comes back.',
                },
              },
            },
          ),
          home: const BodyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Log a weigh-in'), findsWidgets);
      expect(find.textContaining(_exclusionOpening), findsOneWidget);
      // Nothing that needs numbers is drawn.
      expect(find.byType(AgeWaterfall), findsNothing);
      expect(find.text(FitnessTermPanel.title), findsNothing);
      expect(find.text(SleepTermPanel.title), findsNothing);
    });

    test('THE COMPARISON SCALE COMES FROM THE DATA, NOT FROM AN AXIS', () {
      // The prototype hard-codes 70% and 77.7%, an implied nine-hour axis that
      // exists nowhere in the payload. The bars are drawn against the largest
      // quantity in the set instead, so the two lengths are in the same ratio
      // to each other as the numbers and no reference is implied.
      const bars = <ComparisonBar>[
        ComparisonBar('Wearable', 6.3, '6.3h'),
        ComparisonBar('Compared as', 7, '7.0h'),
      ];
      expect(ComparisonBars.scaleOf(bars), 7.0);
      // Nothing measured, nothing to scale against — and so no fill at all.
      expect(
        ComparisonBars.scaleOf(const <ComparisonBar>[
          ComparisonBar('Wearable', null, '—'),
        ]),
        isNull,
      );
    });

    test('the confidence panel does not repeat the exclusion', () {
      final snapshot = TodaySnapshot.fromJson(loadTodayJson());
      final detail = BodyDetail(snapshot: snapshot, reveals: RevealRegistry());
      expect(detail.exclusions, hasLength(1));
      expect(detail.exclusions.single.message, contains(_exclusionOpening));
      // The three caveats stay; the exclusion that rode in with them does not.
      expect(detail.caveats, isNotEmpty);
      expect(detail.caveats, isNot(contains(detail.exclusions.single)));
    });
  });
}
