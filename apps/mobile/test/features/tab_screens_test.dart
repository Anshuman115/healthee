/// The four screens Today's cards moved to — and the proof nothing was lost.
///
/// Cutting Today from twenty sections to six modules is only honest if every
/// removed card **landed somewhere the owner can reach**. This suite is the other
/// half of `today_grid_test.dart`'s door tests: that one asserts each module opens
/// the right tab, this one asserts the card is on it, saying what it always said.
///
/// The assertions are deliberately the SAME strings the Today suite used to make.
/// A card that quietly lost its provenance sentence in the move would otherwise
/// pass a "does the screen render" test and fail nobody.
///
/// It also holds the two rules the move could have broken:
///
///   * **A WITHHELD VALUE IS STILL WITHHELD, WITH ITS REASON AND ITS REMEDY.**
///     The grid is allowed a bare hole because the screen behind it carries both.
///     If a refusal lost its reason in the move, the grid's bargain would be
///     broken on both sides at once and nothing anywhere would say why.
///   * **The insights are no longer a debug readout**, and the statistic is still
///     reachable.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/insights/insights_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';

import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('Sleep', () {
    testWidgets('THE FOUR SLEEP DIMENSIONS ARE NEVER SUMMED', (tester) async {
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
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

    testWidgets('the ladder compares each signal to the OWNER’s baseline', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
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

    testWidgets('the night, the debt and the week are all reachable', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const SleepScreen()));
      await tester.pumpAndSettle();

      for (final card in <String>[
        'Last night',
        'Sleep health',
        'Sleep debt',
        'Your last 7 nights',
        'Blood oxygen overnight',
      ]) {
        await reveal(tester, find.text(card));
        expect(find.text(card), findsOneWidget, reason: '$card moved here');
      }
    });
  });

  group('Activity', () {
    testWidgets('VO₂max names its instrument and its kind of error', (tester) async {
      await tester.pumpWidget(todayHost(store, home: const ActivityScreen()));
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

    testWidgets('biological age shows its levers, its disclaimer and its exclusion', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const ActivityScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Biological age'));

      expect(find.text('34.3'), findsOneWidget);
      expect(find.text('What moves it'), findsOneWidget);
      expect(find.text('Fitness'), findsWidgets);
      expect(find.text('-1.7 y'), findsOneWidget);
      // Verbatim safety statement.
      expect(find.textContaining('not a clinical or diagnostic age'), findsOneWidget);
      // `excluded` here means "regularity is not one of the levers", not "there
      // is no number" — the value stays and the exclusion travels with it.
      expect(
        find.textContaining('Sleep regularity is not one of the levers'),
        findsWidgets,
      );
    });

    testWidgets('the full steps card names the instrument and the number', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const ActivityScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.textContaining('that stream freezes'));

      expect(find.textContaining('Measured by your strap'), findsWidgets);
      expect(
        find.textContaining("The strap's own since-midnight counter"),
        findsOneWidget,
      );
    });

    testWidgets("the strap's calories are labelled as the strap's", (tester) async {
      await tester.pumpWidget(todayHost(store, home: const ActivityScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.textContaining("by the strap's own count"));

      expect(
        find.textContaining("412 kcal by the strap's own count"),
        findsOneWidget,
        reason: "the product's energy model is the server's, not this number",
      );
    });
  });

  group('Insights', () {
    testWidgets('a finding says single-subject, and never says "caused"', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const InsightsScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('In your own data'));

      expect(
        find.textContaining(
          'They say what moved together, never what caused what.',
        ),
        findsOneWidget,
        reason: 'the framing is on the surface, where it cannot be collapsed',
      );
      expect(
        find.textContaining('Single-subject and observational'),
        findsOneWidget,
      );
      expect(
        find.textContaining('moved opposite to'),
        findsOneWidget,
        reason: 'the direction is stated, and it is not a causal verb',
      );
    });

    testWidgets('THE STATISTIC IS BEHIND A DISCLOSURE, NOT ON THE SURFACE', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: const InsightsScreen()));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('The statistic behind this'));

      // The server's `description_raw` is a log line. It reached the home screen
      // verbatim once, which is what this rewrite exists to undo.
      expect(find.textContaining('Spearman('), findsNothing);
      expect(find.textContaining('rho '), findsNothing);
      expect(find.textContaining('q = '), findsNothing);

      // And it IS reachable — one tap, no modal.
      await tester.tap(find.text('The statistic behind this'));
      await tester.pumpAndSettle();
      expect(find.textContaining('rho = -0.42'), findsOneWidget);
      expect(find.textContaining('q = 0.030'), findsOneWidget);
      expect(
        find.textContaining('not that either one caused the other'),
        findsOneWidget,
        reason: 'opening the arithmetic must not mean leaving the caveat behind',
      );
    });

    testWidgets('INSIGHTS IS NOT THE COACH, AND DOES NOT PRETEND TO BE', (
      tester,
    ) async {
      // The findings lived on a tab called Coach with a card underneath saying
      // the coach was not built. Both halves are gone: the coach is a sheet off
      // Today's FAB and it is wired, and this tab is about the history.
      await tester.pumpWidget(todayHost(store, home: const InsightsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Coach'), findsNothing);
      expect(find.textContaining('cannot answer questions yet'), findsNothing);
    });
  });

  group('Diagnostics', () {
    testWidgets('BOTH RESTING HEART RATES ARE HERE AND EACH NAMES ITS INSTRUMENT', (
      tester,
    ) async {
      // The failure the owner caught: 56.2 bpm under Baselines and 63 bpm under
      // From-the-strap, both labelled "resting heart rate", on one screen. They
      // are two instruments. Moving them apart would have hidden that; naming
      // them is what resolves it.
      await tester.pumpWidget(todayHost(store, home: DiagnosticsScreen(now: now)));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('How this one is measured'));
      await tester.tap(find.text('How this one is measured').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('lowest 5-minute average heart rate inside your sleep'),
        findsOneWidget,
      );

      await reveal(tester, find.text('Why this differs from your resting heart rate above'));
      await tester.tap(find.text('Why this differs from your resting heart rate above'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('usually taken awake'),
        findsOneWidget,
        reason: 'the strap row must say which instrument it is',
      );
    });

    testWidgets('the baselines and the strap streams are both reachable', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: DiagnosticsScreen(now: now)));
      await tester.pumpAndSettle();

      expect(find.text('Against your own baseline'), findsOneWidget);
      await reveal(tester, find.text('From the strap'));
      expect(find.text('From the strap'), findsWidgets);
    });

    testWidgets('A WITHHELD STREAM STILL REFUSES IN ITS OWN WORDS', (tester) async {
      // The grid's bargain: a cell shows a bare hole because the screen behind
      // it carries the reason. If the reason vanished in the move, both halves
      // would be broken at once and nothing would say so.
      await tester.pumpWidget(todayHost(store, home: DiagnosticsScreen(now: now)));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('From the strap'));

      expect(find.textContaining('The strap recorded no'), findsWidgets);
    });
  });

  group('a server that cannot be reached', () {
    testWidgets('every tab collapses the derived half into ONE retryable card', (
      tester,
    ) async {
      for (final screen in <Widget>[
        const SleepScreen(),
        const ActivityScreen(),
        const InsightsScreen(),
      ]) {
        await tester.pumpWidget(
          todayHost(store, serverUnreachable: true, home: screen),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining("Couldn't reach your server"),
          findsOneWidget,
          reason: '$screen must say which half failed, once',
        );
        expect(find.text('Try again'), findsOneWidget);
      }
    });
  });
}
