/// Asking the coach — the one place a metered question is spent.
///
/// `keepAlive` so the thread survives the sheet being dismissed: a conversation
/// that vanished when the owner looked something up would cost them the context
/// of a question they have already paid for.
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
  @override
  CoachConversation build() => const CoachConversation();

  /// Asks [question]. Spends one of the owner's included questions.
  ///
  /// Callers must have shown the meter first. That is not a convention here —
  /// `coach_sheet.dart` cannot build an input without an [Entitlement] in hand,
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
    try {
      final answer = await ref.read(coachClientProvider).ask(state.toWire());
      state = state.copyWith(entries: [...state.entries, CoachReply(answer)]);
    } on CoachRefusal catch (refusal) {
      // The gate said no. It is an answer about the account, not a fault, and it
      // carries the instant the window reopens.
      _trouble(refusal.message, spent: false, resetsAt: refusal.resetsAt);
    } on CoachUnreachable catch (failure) {
      _trouble(failure.message, spent: false);
    } finally {
      // Whatever happened — including the two `on` clauses above and anything
      // they did not catch — the balance is re-read from the server rather than
      // guessed at. See the library docstring.
      ref.invalidate(coachEntitlementProvider);
      state = state.copyWith(asking: false);
    }
  }

  /// Starts a fresh thread. The old one is dropped, not archived: nothing in this
  /// app persists a conversation, and a "history" button over a list that dies
  /// with the process would be a promise the storage layer does not keep.
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
