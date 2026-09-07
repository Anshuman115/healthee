/// The coach's thread must be endable, because every question re-sends it.
///
/// `CoachController.ask` sends `state.toWire()` — the WHOLE conversation — on
/// every question, and the notifier is `keepAlive`, so the thread outlives the
/// screen. The owner's allowance is 20 questions per rolling 30 days at a
/// measured cost each, so a thread that only grows makes the twentieth question
/// carry all nineteen before it.
///
/// The control was removed when the coach became a route, on the grounds that
/// the prototype's coach screen draws none. That was right about the prototype
/// and wrong about the app: the design never modelled a thread that persists,
/// and it matters more now that the coach can be opened **about something**
/// (`?topic=`) — arriving from a workout on top of an unrelated conversation
/// asks the model to answer in a context the owner did not choose.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/features/coach/coach_conversation.dart';

void main() {
  test('A THREAD THAT CANNOT BE ENDED ONLY GROWS', () {
    const empty = CoachConversation();
    const started = CoachConversation(
      entries: <CoachEntry>[OwnerQuestion('one'), OwnerQuestion('two')],
    );
    expect(empty.isEmpty, isTrue);
    expect(started.isEmpty, isFalse);
    expect(
      started.toWire().length,
      greaterThan(empty.toWire().length),
      reason: 'every earlier turn is re-sent with the next question',
    );
  });

  test('a trouble entry is not a turn — it never reaches the model', () {
    // The union has three kinds and only two are conversation. A fourth kind
    // silently dropped here would be context the owner can see and the coach
    // cannot.
    const withTrouble = CoachConversation(
      entries: <CoachEntry>[
        OwnerQuestion('one'),
        CoachTrouble(message: 'not answered', spent: false),
      ],
    );
    expect(withTrouble.toWire().length, 1);
  });
}
