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

  /// True when the last attempt ended in something less than a full send.
  ///
  /// `skipped` is deliberately included: not being signed in is not a fault, but
  /// it IS a reason the server has nothing, and the card must be able to say so.
  bool get lastAttemptIncomplete =>
      outcomeId != null && outcomeId != 'sent';

  /// Whether this is worth telling the owner about at all.
  ///
  /// Nothing pending and nothing failed says nothing — the same rule the data
  /// health card follows. Silence when all is well is what makes the card
  /// meaningful when it speaks.
  bool get needsAttention => pendingRows > 0 || failureReason != null;
}
