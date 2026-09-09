/// Conversations survive the process, and survive it INTACT.
///
/// The defect this closes: a thread lived in a `keepAlive` provider, so an answer
/// the owner had been charged one of twenty for vanished when the app restarted,
/// with no record it had existed. Storing it is only worth doing if what comes
/// back is the same thing that went in — an answer stripped of the grade floor or
/// the citations that qualify it would be worse than no history, because it would
/// look complete.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/coach/coach_answer.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/data/coach/coach_history_store.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/coach/coach_conversation.dart';

void main() {
  late LocalStore store;
  late CoachHistoryStore history;

  setUp(() {
    store = LocalStore.memory();
    history = CoachHistoryStore(store);
  });
  tearDown(() async => store.close());

  const String scope = 'owner-a';
  final DateTime at = DateTime.utc(2026, 9, 9, 8, 30);

  Future<void> seedThread(
    String id, [
    String opening = 'Opening?',
    String s = scope,
  ]) => history.open(scope: s, threadId: id, opening: opening, at: at);

  group('a conversation comes back whole', () {
    test('a reply keeps its citations, grade floor and validation', () async {
      await seedThread('t1', 'What should I make of my sleep debt (33 h)?');
      await history.append(
        scope: scope,
        threadId: 't1',
        seq: 0,
        entry: const OwnerQuestion(
          'What should I make of my sleep debt (33 h)?',
        ),
        at: at,
      );
      await history.append(
        scope: scope,
        threadId: 't1',
        seq: 1,
        entry: const CoachReply(
          CoachAnswer(
            reply: 'Your debt is near 33 hours [sleep_need_debt].',
            citations: <String>['sleep_need_debt', 'sleep_and_recovery'],
            gradeFloor: 'Probable',
            refused: false,
            validated: true,
          ),
        ),
        at: at,
      );

      final entries = await history.entries(scope: scope, threadId: 't1');

      expect(entries, hasLength(2));
      expect((entries[0] as OwnerQuestion).text, contains('sleep debt'));
      final reply = (entries[1] as CoachReply).answer;
      // Each of these qualifies every sentence in the reply. A history that
      // dropped one would render an answer as more certain than it was.
      expect(reply.citations, <String>[
        'sleep_need_debt',
        'sleep_and_recovery',
      ]);
      expect(reply.gradeFloor, 'Probable');
      expect(reply.validated, isTrue);
      expect(reply.refused, isFalse);
    });

    test('a FAILURE is kept too, with what it did to the meter', () async {
      // A question that failed still cost the owner an attempt. A history that
      // quietly dropped the failures would be a record of only the good days.
      await seedThread('t2', 'Anything about my HRV?');
      await history.append(
        scope: scope,
        threadId: 't2',
        seq: 0,
        entry: const CoachTrouble(
          message: "Couldn't reach your server.",
          charge: CoachCharge.notCharged,
        ),
        at: at,
      );

      final entries = await history.entries(scope: scope, threadId: 't2');

      expect(entries, hasLength(1));
      expect((entries[0] as CoachTrouble).charge, CoachCharge.notCharged);
    });

    test('turns come back in the order they were added', () async {
      await seedThread('t3', 'First?');
      for (var i = 0; i < 5; i++) {
        await history.append(
          scope: scope,
          threadId: 't3',
          seq: i,
          entry: OwnerQuestion('q$i'),
          at: at,
        );
      }

      final entries = await history.entries(scope: scope, threadId: 't3');

      expect(
        <String>[for (final e in entries) (e as OwnerQuestion).text],
        <String>['q0', 'q1', 'q2', 'q3', 'q4'],
      );
    });
  });

  group('the sign-in scope is a wall, not a filter', () {
    test("one owner's threads are invisible to another", () async {
      // Without this a second owner signing in on one handset reads the first
      // owner's conversations out of the local database — the isolation the
      // server enforces, undone on the client.
      await seedThread('mine', 'My question?');
      await seedThread('theirs', 'Their question?', 'owner-b');

      final mine = await history.threads(scope);
      final theirs = await history.threads('owner-b');

      expect(<String>[for (final t in mine) t.id], <String>['mine']);
      expect(<String>[for (final t in theirs) t.id], <String>['theirs']);
    });

    test('and their turns are too', () async {
      await seedThread('shared-id');
      await seedThread('shared-id', 'Theirs', 'owner-b');
      await history.append(
        scope: 'owner-b',
        threadId: 'shared-id',
        seq: 0,
        entry: const OwnerQuestion('theirs'),
        at: at,
      );

      // The SAME thread id under two scopes. A query that filtered on the id
      // alone would hand this owner the other's turn.
      expect(
        await history.entries(scope: scope, threadId: 'shared-id'),
        isEmpty,
      );
      expect(
        await history.entries(scope: 'owner-b', threadId: 'shared-id'),
        hasLength(1),
      );
    });
  });

  group('the list stays in step with the conversations', () {
    test('a thread reports its turn count and its last movement', () async {
      await seedThread('t4', 'Opening?');
      await history.append(
        scope: scope,
        threadId: 't4',
        seq: 0,
        entry: const OwnerQuestion('Opening?'),
        at: at,
      );
      await history.append(
        scope: scope,
        threadId: 't4',
        seq: 1,
        entry: const OwnerQuestion('Second'),
        at: at.add(const Duration(minutes: 5)),
      );

      final thread = (await history.threads(scope)).single;

      expect(thread.turns, 2);
      expect(thread.lastAt, at.add(const Duration(minutes: 5)));
      expect(thread.startedAt, at);
      expect(thread.opening, 'Opening?');
    });

    test('threads are listed most recently moved first', () async {
      await seedThread('older', 'Older');
      await seedThread('newer', 'Newer');
      await history.append(
        scope: scope,
        threadId: 'newer',
        seq: 0,
        entry: const OwnerQuestion('x'),
        at: at.add(const Duration(hours: 2)),
      );

      expect(
        <String>[for (final t in await history.threads(scope)) t.id],
        <String>['newer', 'older'],
      );
    });

    test('forgetting one takes its turns with it, and only its own', () async {
      await seedThread('keep', 'Keep');
      await seedThread('drop', 'Drop');
      await history.append(
        scope: scope,
        threadId: 'keep',
        seq: 0,
        entry: const OwnerQuestion('kept'),
        at: at,
      );
      await history.append(
        scope: scope,
        threadId: 'drop',
        seq: 0,
        entry: const OwnerQuestion('dropped'),
        at: at,
      );

      await history.forget(scope: scope, threadId: 'drop');

      expect(
        <String>[for (final t in await history.threads(scope)) t.id],
        <String>['keep'],
      );
      expect(await history.entries(scope: scope, threadId: 'drop'), isEmpty);
      expect(
        await history.entries(scope: scope, threadId: 'keep'),
        hasLength(1),
      );
    });
  });
}
