/// ⛔ A program the coach designed must reach a screen.
///
/// It did not. `create_program` wrote a ladder with status `suggested`,
/// `GET /api/programs` served it correctly with every field the client parses —
/// and nothing drew it. `actions_screen.dart` mounts only the RUNNING section, on
/// the stated principle that "what was merely on offer is in the deck above", and
/// the deck knew about two feeds of the three: recommendations and suggested
/// challenges. Programs were never added.
///
/// Found on a real install: the coach designed a six-week ladder, the owner went
/// looking for it, and it was nowhere. It is also why that program is still
/// `suggested` with no `adopted_at` — there was never a button to press.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/actions/actions_screen.dart';

import '_settings_harness.dart' show tallViewport;
import '_today_host.dart';

Challenge _rung(int id, double target) => Challenge(
  id: id,
  title: 'Rung $id',
  why: 'Because it builds.',
  status: 'locked',
  metric: 'steps_total',
  target: target,
  comparator: '>=',
  cadence: 'daily',
  windowDays: 14,
  difficulty: 'standard',
  kind: 'threshold',
  citations: const <String>[],
);

final HealthProgram _ladder = HealthProgram(
  id: 2,
  title: 'Progressive Walking Step Volume Ladder',
  why: 'A gradual build in daily step volume.',
  status: 'suggested',
  rungs: <Challenge>[_rung(6, 5000), _rung(7, 5250), _rung(8, 5500)],
  settledRungs: 0,
  goal: 'Raise daily steps',
  weeks: 6,
);

void main() {
  late LocalStore store;
  final DateTime now = DateTime(2026, 9, 11, 9);

  setUp(() => store = LocalStore.memory());
  tearDown(() => store.close());

  testWidgets('A SUGGESTED PROGRAM APPEARS IN THE DECK', (tester) async {
    tallViewport(tester);
    await tester.pumpWidget(
      todayHost(
        store,
        home: ActionsScreen(now: now),
        suggestedPrograms: <HealthProgram>[_ladder],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Progressive Walking Step Volume Ladder'),
      findsOneWidget,
      reason: 'the program was stored and served but drawn nowhere',
    );
  });

  testWidgets('it names the SEQUENCE, not one rung\'s target', (tester) async {
    // A ladder does not commit you to a number, it commits you to an order.
    // Quoting the first rung's target would read as the whole commitment when it
    // is only the first step — and the point of a ladder is that the target moves.
    tallViewport(tester);
    await tester.pumpWidget(
      todayHost(
        store,
        home: ActionsScreen(now: now),
        suggestedPrograms: <HealthProgram>[_ladder],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3 rungs'), findsOneWidget);
    expect(
      find.textContaining('5000'),
      findsNothing,
      reason: "the first rung's target is not the program's commitment",
    );
  });

  testWidgets('no program, no card — and nothing breaks', (tester) async {
    tallViewport(tester);
    await tester.pumpWidget(todayHost(store, home: ActionsScreen(now: now)));
    await tester.pumpAndSettle();

    expect(find.textContaining('rungs'), findsNothing);
  });
}
