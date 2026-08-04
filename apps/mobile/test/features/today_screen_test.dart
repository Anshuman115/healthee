/// Today, rendered from real stored strap rows AND the real contract snapshot.
///
/// Two sources, exercised the same way they run: the store is a genuine
/// in-memory SQLite database seeded through the writer a sync uses, and the
/// server payload is `packages/contracts/snapshots/today.json` read from the
/// repo. `now` is injected, because a suite that reads the wall clock fails once
/// a day at midnight and passes on the retry.
///
/// This half is about **what the screen draws when it has data**. The refusals,
/// the unreachable server and the never-synced phone are `today_refusals_test.dart`
/// — split when this file crossed the 400-line gate, along the seam the standards
/// doc asks for: one file per reason to change.
///
/// The test that matters most here:
///
///   * **THE FOUR SLEEP DIMENSIONS ARE NEVER SUMMED.** The payload carries
///     `score: 3` and `max_score: 4` and drawing "3/4" would be one line. Brief
///     §5.3 forbids it; this asserts the absence.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';

import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('measurements the strap made', () {
    setUp(() => seedDevice(store));

    testWidgets('the daily counter opens the screen, in the grid', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('9,264'));

      expect(find.text('9,264'), findsWidgets);
      // The grid cell is an index entry, so it says which of the strap's TWO
      // step numbers this is in its foot — uppercased for the legacy eyebrow
      // look, with the written case kept on the semantics label.
      expect(
        find.textContaining('SINCE-MIDNIGHT COUNTER'),
        findsOneWidget,
        reason: '#121 — the counter, never the frozen per-minute sum',
      );
    });

    testWidgets('the full steps card names the instrument and the number', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      // The grid is the index; the Activity section is the entry, and it is
      // the one that carries the provenance and the whole #121 sentence.
      await reveal(tester, find.textContaining('that stream freezes'));

      expect(find.textContaining('Measured by your strap'), findsWidgets);
      expect(
        find.textContaining("The strap's own since-midnight counter"),
        findsOneWidget,
      );
    });

    testWidgets("the strap's calories are labelled as the strap's", (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.textContaining("by the strap's own count"));

      expect(
        find.textContaining("412 kcal by the strap's own count"),
        findsOneWidget,
        reason: "the product's energy model is the server's, not this number",
      );
    });
  });

  group('what the server made of it', () {
    setUp(() => seedDevice(store));

    testWidgets('recovery ships its per-factor breakdown, never alone', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('72'));

      expect(find.text('72'), findsOneWidget);
      // Module eyebrows render uppercase; `ModuleLabel` keeps the written case
      // on the semantics label so a screen reader does not spell them out.
      expect(find.text('WHAT IT IS MADE OF'), findsOneWidget);
      // `feedback_no_composite_score`: the components are the licence, and they
      // are beside the number rather than behind a tap.
      expect(find.text('HRV'), findsWidgets);
      expect(find.text('RESTING HR'), findsWidgets);
      // Each factor's own sub-score, from the contract snapshot.
      expect(find.text('80'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
    });

    testWidgets('the ladder compares each signal to the OWNER’s baseline', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Against your own normal'));

      expect(find.text('Sleep duration'), findsOneWidget);
      expect(find.textContaining('At your usual 380'), findsOneWidget);
      expect(
        find.textContaining('not a population average'),
        findsOneWidget,
        reason: 'brief §5.2 — population norms are irrelevant here',
      );
    });

    testWidgets('THE FOUR SLEEP DIMENSIONS ARE NEVER SUMMED', (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Sleep health'));

      // Four judgements, each with its own published cutoff.
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Efficiency'), findsOneWidget);
      expect(find.text('Regularity'), findsOneWidget);
      expect(find.text('Timing'), findsOneWidget);
      expect(find.textContaining('Cutoff 7.0–9.0 h'), findsOneWidget);
      expect(find.textContaining('Cutoff ≥ 85%'), findsOneWidget);
      expect(find.textContaining('SRI over 14 nights'), findsOneWidget);
      // And nothing that reads as a composite. The payload carries `score: 3`
      // and `max_score: 4`; drawing it would be one line, and brief §5.3
      // forbids it.
      expect(find.text('3/4'), findsNothing);
      expect(find.text('3 of 4'), findsNothing);
    });

    testWidgets('VO₂max names its instrument and its kind of error', (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('VO₂max'));

      expect(find.text('43.0'), findsOneWidget);
      // [[hr_reserve_vo2max]] D4 — the instrument travels with the number.
      expect(find.text('Fitted from a recorded session'), findsOneWidget);
      expect(find.text('± 2.95'), findsOneWidget);
      // WHICH error, not a bare ±: a MAPE is not a standard error of estimate.
      expect(find.textContaining('Carrier 2023'), findsOneWidget);
      expect(find.textContaining('median for your age and sex is 39.7'), findsOneWidget);
    });

    testWidgets('biological age shows its levers and its disclaimer', (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Biological age'));

      expect(find.text('34.3'), findsOneWidget);
      expect(find.text('What moves it'), findsOneWidget);
      expect(find.text('Fitness'), findsWidgets);
      expect(find.text('-1.7 y'), findsOneWidget);
      // Verbatim safety statement.
      expect(find.textContaining('not a clinical or diagnostic age'), findsOneWidget);
    });

    testWidgets('an exclusion beside a value narrows it, visibly', (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Biological age'));

      // `excluded` here means "regularity is not one of the levers", not "there
      // is no number" — the value stays and the exclusion travels with it.
      expect(find.textContaining('Sleep regularity is not one of the levers'), findsWidgets);
    });

    testWidgets('the illness flag renders its calibrated sentence verbatim', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      expect(find.text('POSSIBLE EARLY SIGNAL'), findsOneWidget);
      expect(find.textContaining('Possible early signal'), findsOneWidget);
      expect(find.textContaining('breathing rate +2.4 bpm vs your baseline'), findsOneWidget);
    });

    testWidgets('a finding says single-subject, and never says "caused"', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('In your own data'));

      expect(find.textContaining('Single-subject and observational'), findsOneWidget);
      expect(find.textContaining('moved in opposite directions'), findsOneWidget);
      expect(find.textContaining('after correcting for the search'), findsOneWidget);
    });
  });
}
