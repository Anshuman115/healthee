/// Today, rendered from real stored strap rows AND the real contract snapshot.
///
/// Two sources, exercised the same way they run: the store is a genuine
/// in-memory SQLite database seeded through the writer a sync uses, and the
/// server payload is `packages/contracts/snapshots/today.json` read from the
/// repo. `now` is injected, because a suite that reads the wall clock fails once
/// a day at midnight and passes on the retry.
///
/// The tests that matter most, both mutation-checked:
///
///   * **A WITHHELD VALUE IS NEVER A BARE NUMBER.** A screen that renders a
///     number where the payload sent a refusal is the one bug this whole
///     architecture exists to make impossible, and it is the last hop — the
///     compiler can force the switch, but only a test can prove the branch draws
///     the hole.
///   * **THE FOUR SLEEP DIMENSIONS ARE NEVER SUMMED.** The payload carries
///     `score: 3` and `max_score: 4` and drawing "3/4" would be one line. Brief
///     §5.3 forbids it; this asserts the absence.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

import '../_today_stubs.dart';
import '../store/strap_store_test.dart' show resultWith;
import '_today_host.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('measurements the strap made', () {
    setUp(() => seedDevice(store));

    testWidgets('the daily counter is on screen, and says which number it is', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('9,264'));

      expect(find.text('9,264'), findsOneWidget);
      expect(find.textContaining('Measured by your strap'), findsWidgets);
      // And which of the strap's TWO step numbers this is (#121).
      expect(find.textContaining('since-midnight counter'), findsOneWidget);
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
      expect(find.text('What it is made of'), findsOneWidget);
      // `feedback_no_composite_score`: the components are the licence.
      expect(find.text('HRV'), findsWidgets);
      expect(find.text('Resting HR'), findsWidgets);
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

  group('refusals', () {
    testWidgets('A WITHHELD VALUE IS NEVER A BARE NUMBER', (tester) async {
      // Nothing but heart rate, so the strap's own steps have no counter behind
      // them; and VO₂max withheld the way production withholds it.
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68)]),
      );
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => {
              ...json,
              'vo2max': <String, Object?>{
                ...json['vo2max']! as Map<String, Object?>,
                'estimate': null,
                'method': null,
                'method_caveat': null,
                'data_confidence': 'insufficient_data',
                'withheld': <String, Object?>{
                  'reason': 'logged_weight_stale',
                  'message':
                      'The last weight you logged is more than two weeks old, '
                      "so we can't call it your weight today — log a new one "
                      'and this comes straight back.',
                  'last_as_of_date': '2026-06-04',
                  'age_days': 57,
                  // The server puts the stale value INSIDE the block, "where
                  // nothing can mistake it for today's". This is the number a
                  // careless parser would promote back to the headline, so the
                  // fixture carries it on purpose.
                  'last_estimate': 43.0,
                },
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Scroll to the REMEDY rather than to the word: several blocks can be
      // withheld at once, and "the first WITHHELD on screen" is not this one.
      final remedy = find.textContaining('log a new one');
      await reveal(tester, remedy);

      final card = find.ancestor(of: remedy, matching: find.byType(StateCard));
      expect(
        find.descendant(of: card, matching: find.text('WITHHELD')),
        findsOneWidget,
      );
      // The card keeps its footprint and its title, and the value slot carries
      // the reason: a number-shaped hole, the word, and the remedy.
      expect(
        find.descendant(of: card, matching: find.byType(ValueHole)),
        findsWidgets,
      );
      expect(
        find.text('43.0'),
        findsNothing,
        reason: 'the withheld estimate must not appear anywhere as a number',
      );
      // A withhold is an answer, so it never offers a retry.
      expect(
        find.descendant(of: card, matching: find.text('Try again')),
        findsNothing,
      );
    });

    testWidgets('A WITHHELD METRIC ROW SHOWS A HOLE, NOT ITS BASELINE', (
      tester,
    ) async {
      // The last-hop bug this architecture exists to prevent, in its most
      // tempting form: the row HAS a 30-day median sitting right there, and
      // drawing it where today's value goes would look completely normal and be
      // a number the owner never recorded.
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'metrics': [
                for (final card in json['metrics']! as List)
                  if ((card as Map<String, Object?>)['metric'] == 'rhr_daily')
                    <String, Object?>{
                      ...card,
                      'value': null,
                      'z': null,
                      'data_confidence': 'insufficient_data',
                      'withheld': <String, Object?>{
                        'reason': 'insufficient_nights',
                        'message':
                            'Fewer than 3 nights of resting heart rate in the '
                            'last week — wear the strap overnight for a few '
                            'more nights and this comes back.',
                      },
                    }
                  else
                    card,
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Against your own baseline'));

      final strip = find.ancestor(
        of: find.text('Against your own baseline'),
        matching: find.byType(StateCard),
      );
      expect(
        find.descendant(of: strip, matching: find.textContaining('wear the strap overnight')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: strip, matching: find.byType(ValueHole)),
        findsWidgets,
      );
      expect(
        find.descendant(of: strip, matching: find.text('55')),
        findsNothing,
        reason: 'the 30-day median is not a stand-in for a value we do not have',
      );
    });

    testWidgets('the strap and the server refuse in their own words', (tester) async {
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68)]),
      );
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.textContaining('The strap recorded no steps'));

      // A stream the sensor did not write says "wear it". Collapsing that into
      // a server withhold would send the owner to the wrong place.
      expect(find.textContaining('The strap recorded no'), findsWidgets);
    });
  });

  group('the server is unreachable', () {
    testWidgets('the measurements still render, and the failure is ONE card', (
      tester,
    ) async {
      await seedDevice(store);
      await tester.pumpWidget(todayHost(store, serverUnreachable: true));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Couldn't reach your server"),
        findsOneWidget,
        reason: 'twenty error cards is the same news said twenty times',
      );
      expect(find.text('Try again'), findsOneWidget);
      await reveal(tester, find.text('9,264'));
      expect(
        find.text('9,264'),
        findsOneWidget,
        reason: 'brief §7.4 — the app must be readable with no network',
      );
    });

    testWidgets('a cached payload says it is cached, and dates itself', (tester) async {
      await seedDevice(store);
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            fromCache: true,
            fetchedAt: now.subtract(const Duration(days: 3)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data health'), findsOneWidget);
      expect(
        find.textContaining('it describes 2026-07-31, 3 d ago'),
        findsOneWidget,
        reason: 'a fallback that hides itself is stale-as-current',
      );
    });

    testWidgets('a push backlog is said out loud, not hidden', (tester) async {
      await seedDevice(store);
      await store.pushReader.stampAttempt(
        at: now.subtract(const Duration(hours: 2)),
        outcomeId: 'failed',
        complete: false,
        failureReason: 'it could not be reached',
      );
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('measurements are waiting here to reach the server'),
        findsOneWidget,
      );
      expect(find.textContaining('it could not be reached'), findsOneWidget);
    });
  });

  group('a phone that has never synced and has never reached the server', () {
    testWidgets('says so once, rather than twenty times', (tester) async {
      await tester.pumpWidget(todayHost(store, serverUnreachable: true));
      await tester.pumpAndSettle();

      expect(find.text('Nothing from your strap yet'), findsOneWidget);
      expect(find.textContaining('nothing is estimated'), findsOneWidget);
      expect(find.textContaining('never — nothing has been pulled'), findsOneWidget);
    });
  });

}
