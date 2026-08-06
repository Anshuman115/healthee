/// What the app knows about its own pushing — the half of sync health the
/// strap cannot tell you.
///
/// `DeviceSyncStamp` answers "did we read the strap"; this answers "did the
/// server hear about it". Two separate facts, and this product has already
/// learned the cost of conflating a read with a write: a screen that shows a
/// healthy sync while a fortnight of measurements sit in a local table is a
/// screen that looks fine and is not.
///
/// [pendingRows] is therefore always present, not only on failure. A number that
/// only appears when something is wrong is a number nobody trusts when it does.
library;

import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/store/prune_report.dart';
import 'package:meta/meta.dart';

/// The last push attempt, and what is still waiting behind it.
@immutable
class PushStamp {
  /// Read out of [SyncMeta] by `PushReader.lastAttempt`.
  const PushStamp({
    required this.pendingRows,
    this.lastCompletePush,
    this.lastAttempt,
    this.outcomeId,
    this.failureReason,
    this.loss,
  });

  /// A phone that has never pushed and is holding nothing.
  const PushStamp.never() : this(pendingRows: 0);

  /// How many measured rows have not reached the server.
  final int pendingRows;

  /// When a push last sent everything pending. Null until one has.
  final DateTime? lastCompletePush;

  /// When a push was last attempted, complete or not.
  final DateTime? lastAttempt;

  /// The last attempt's outcome id — `sent`, `partial`, `failed`, `skipped`.
  final String? outcomeId;

  /// Why the last attempt did not finish, in the owner's own words. Null after
  /// a good push, because a cleared failure must not read as a current one.
  final String? failureReason;

  /// Measurements this phone destroyed before the server ever saw them.
  ///
  /// It belongs here rather than beside the prune that caused it: this is the
  /// type that answers "what does the server not have", and rows the local
  /// store deleted while still pending are the most final possible answer to
  /// that question. Null on every phone that has never lost one, which is every
  /// phone whose push has not been broken for a year.
  final UnsentLoss? loss;

  /// True when the last attempt ended in something less than a full send.
  ///
  /// `skipped` is deliberately included: not being signed in is not a fault, but
  /// it IS a reason the server has nothing, and the card must be able to say so.
  bool get lastAttemptIncomplete =>
      outcomeId != null && outcomeId != PushOutcomeId.sent;

  /// Whether something went WRONG, as opposed to something being unfinished.
  ///
  /// Keyed on the reason rather than on the id, because `_stamp` writes a reason
  /// only for a fault and a store written by an older build can still hold the
  /// retired `partial` id — which always had a reason beside it, so it reads as
  /// a fault here. Wrong in the loud direction, and it clears on the next push.
  bool get isFaulted => failureReason != null;

  /// Whether the backlog is being worked through right now, and is not stuck.
  ///
  /// A push that stopped at its own page cap left real data on the server and
  /// will continue. The card shows quiet progress for this and never a fault —
  /// see `push_outcome.dart` for why the two stopped being one case.
  bool get isDraining => outcomeId == PushOutcomeId.paused;

  /// Whether the last attempt was not made because this phone has no token.
  bool get isSignedOut => outcomeId == PushOutcomeId.skipped;

  /// Whether this is worth telling the owner about at all.
  ///
  /// Nothing pending and nothing failed says nothing — the same rule the data
  /// health card follows. Silence when all is well is what makes the card
  /// meaningful when it speaks.
  ///
  /// A past [loss] counts even when the queue is empty and the last push was
  /// clean: the measurements are still gone, and a card that goes quiet about
  /// destroyed data the moment the symptom clears would be reporting tidiness
  /// rather than truth.
  bool get needsAttention => pendingRows > 0 || isFaulted || loss != null;
}
