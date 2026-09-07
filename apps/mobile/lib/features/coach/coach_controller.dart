/// Asking the coach — the one place a metered question is spent.
///
/// `keepAlive` so the thread survives the screen being left: a conversation that
/// vanished when the owner looked something up would cost them the context of a
/// question they have already paid for.
///
/// ## The meter is re-read after every attempt, always
///
/// Not decremented. `routers/coach.py` refunds the question on a refusal, on an
/// unvalidated answer and on a transport failure, so a local subtraction would be
/// wrong in three of the five outcomes — and wrong the flattering way round, which
/// is the direction this product treats as a defect rather than a rounding.
/// [ask] invalidates `coachEntitlementProvider` in a `finally`, so the number
/// beside the input is the server's after every attempt including the ones that
/// threw.
///
/// ## Every failure lands in the thread
///
/// A [CoachTrouble] entry is appended for each one, saying what happened and
/// whether anything was charged. Standards §1 forbids a swallowed failure, and
/// the honesty contract makes a silent one worse here than anywhere else in the
/// app: the surface has a running cost attached to it.
library;

import 'package:healthee/core/logging.dart';
import 'package:healthee/data/coach/coach_client.dart';
import 'package:healthee/features/coach/coach_conversation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'coach_controller.g.dart';

/// The running conversation with the coach.
@Riverpod(keepAlive: true)
class CoachController extends _$CoachController {
  int _generation = 0;
  @override
  CoachConversation build() {
    ref.watch(coachClientProvider);
    _generation++;
    return const CoachConversation();
  }

  /// Asks [question]. Spends one of the owner's included questions.
  ///
  /// Callers must have shown the meter first. That is not a convention here —
  /// `coach_screen.dart` cannot build an input without an [Entitlement] in hand,
  /// so there is no path from a screen to this method that skipped the number.
  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.asking) {
      return;
    }
    state = state.copyWith(
      entries: [...state.entries, OwnerQuestion(text)],
      asking: true,
    );
    final generation = _generation;
    try {
      final answer = await ref.read(coachClientProvider).ask(state.toWire());
      if (_isCurrent(generation)) {
        state = state.copyWith(entries: [...state.entries, CoachReply(answer)]);
      }
    } on CoachRefusal catch (refusal) {
      // The gate said no. It is an answer about the account, not a fault, and it
      // carries the instant the window reopens.
      if (_isCurrent(generation)) {
        _trouble(refusal.message, spent: false, resetsAt: refusal.resetsAt);
      }
    } on CoachUnreachable catch (failure) {
      if (_isCurrent(generation)) _trouble(failure.message, spent: false);
    } finally {
      // Whatever happened — including the two `on` clauses above and anything
      // they did not catch — the balance is re-read from the server rather than
      // guessed at. See the library docstring.
      if (_isCurrent(generation)) {
        ref.invalidate(coachEntitlementProvider);
        state = state.copyWith(asking: false);
      }
    }
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  /// Drops the thread and starts an empty one.
  ///
  /// **Not a tidiness control — a cost and a clarity one.** [ask] sends
  /// `state.toWire()`, the WHOLE conversation, on every question, and this
  /// notifier is `keepAlive` so the thread outlives the screen. Without a way
  /// to end it, each question carries every earlier one: the owner's allowance
  /// is 20 questions per rolling 30 days at a measured $0.179 each, and a
  /// thread that only grows makes the twentieth cost far more than the first.
  ///
  /// It matters more since the coach became a route that can be opened **about
  /// something** (`?topic=`). Arriving from a workout on top of an unrelated
  /// ten-turn conversation asks the model to answer in a context the owner did
  /// not choose.
  ///
  /// The prototype's coach screen draws no such control, so this is a
  /// deliberate departure from it: the design never modelled a thread that
  /// persists, and the honesty layer is where that gets paid for.
  void newThread() => state = const CoachConversation();

  void _trouble(String message, {required bool spent, DateTime? resetsAt}) {
    AppLog.info('coach', 'question not answered: $message');
    state = state.copyWith(
      entries: [
        ...state.entries,
        CoachTrouble(message: message, spent: spent, resetsAt: resetsAt),
      ],
    );
  }
}
