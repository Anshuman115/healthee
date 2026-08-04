/// How one sync ended — and the distinction the whole engine turns on.
///
/// ## Partial is not a shade of complete
///
/// A pull can end three ways, and only one of them may move the timestamp the
/// screen shows as "up to date":
///
/// ```text
///   complete   the whole fetch plan ran and the daily counter landed
///   partial    something reached the store, but not all of it
///   failed     nothing reached the store
/// ```
///
/// The engine writes `last_attempt_ms` on all three and `last_complete_sync_ms`
/// on the first only, so a half-finished pull cannot make the app look current.
/// That is the brief's "partial state must not be presented as complete",
/// enforced at the write rather than trusted at the render — a screen that
/// forgets to check a flag would otherwise undo it.
///
/// [SyncPartial] carries a [reason] in the owner's own words because "partial"
/// on its own is not actionable. "The strap did not report its daily step
/// counter" tells someone what is missing; a badge does not.
library;

import 'package:healthee/data/sync/sync_failure.dart';
import 'package:meta/meta.dart';

/// The result of one sync attempt.
@immutable
sealed class SyncOutcome {
  /// Base constructor. Use one of the cases.
  const SyncOutcome();

  /// The id stored in [SyncMeta] and asserted on in tests.
  String get id;

  /// Whether this attempt may move "last complete sync". Only [SyncComplete].
  bool get isComplete => this is SyncComplete;

  /// A sentence for the sync-health line. Never empty.
  String get summary;
}

/// The whole fetch plan ran, and the daily counter landed with it.
final class SyncComplete extends SyncOutcome {
  /// [storedSamples] is what actually reached the store, for the log line.
  const SyncComplete({required this.storedSamples, required this.prunedRows});

  /// How many samples this pull wrote.
  final int storedSamples;

  /// How many rows fell outside the 60-day horizon and were dropped.
  final int prunedRows;

  @override
  String get id => 'complete';

  @override
  String get summary => 'Synced $storedSamples samples';
}

/// Some data reached the store; the pull was not the whole plan.
final class SyncPartial extends SyncOutcome {
  /// [reason] says what is missing, in the second person where it helps.
  const SyncPartial(this.reason);

  /// What did not happen. Shown, not swallowed.
  final String reason;

  @override
  String get id => 'partial';

  @override
  String get summary => 'Partial sync — $reason';
}

/// Nothing reached the store, and here is the named failure.
final class SyncFailed extends SyncOutcome {
  /// [failure] keeps the originating taxonomy's headline and remedy.
  const SyncFailed(this.failure);

  /// Why it stopped.
  final SyncFailure failure;

  @override
  String get id => 'failed';

  @override
  String get summary => failure.headline;
}
