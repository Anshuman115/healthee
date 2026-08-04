/// Where the app stands with the strap, right now — a first-class state.
///
/// ## "Connected" is a claim about the present, and it is guarded structurally
///
/// The temptation in every app that talks to a device is to call itself
/// connected when it holds credentials, or when a connection succeeded once and
/// nothing has told it otherwise. Both are claims about the past wearing the
/// present tense. Here [Connected] means exactly one thing: **an authenticated
/// session is open at this moment.**
///
/// That is enforced rather than promised, in four places that all have to agree:
///
///   1. [Connected] cannot be constructed without a [Connected.since] instant,
///      and every instant that exists comes from `StrapSession.authenticatedAt`,
///      which is written on the same line that emits `StrapPhase.authenticated`
///      — after the strap accepted the proof. There is no path from "we have a
///      MAC and a key" to this case.
///   2. Both producers — `SyncEngine` and `ForegroundLink` — build it from a
///      session that answers `isOpen`, which goes false on the first line of
///      `close()`. A held session is therefore re-checked, never remembered.
///   3. `SyncEngine` returns the state to a resting case in a `finally`, so the
///      session closing and the state leaving [Connected] are the same unwind.
///   4. `test/sync/sync_engine_test.dart` runs a strap that refuses the key and
///      asserts [Connected] never appears in the whole transcript;
///      `test/sync/foreground_link_test.dart` asserts a backgrounded app holds
///      no session and never publishes the case.
///
/// ## The resting states carry a fact, not a mood
///
/// [Disconnected] and [ConnectionFailed] both carry `lastCompleteSync`, because
/// the useful thing to say when no session is open is *when the strap was last
/// read* — not that a socket is shut. `link_report.dart` owns the wording; this
/// file owns the facts, and keeping those apart is what lets the wording be
/// tested against a pinned clock.
///
/// ## Why a sealed union and not a status enum with side-car fields
///
/// The same argument `Reading` makes. An enum plus `progress`, plus `failure`,
/// plus `battery` can express `connected` with a failure attached and `failed`
/// with no reason, and lets a widget read the enum and ignore the rest. The
/// union makes the illegal states unrepresentable and makes a new state a
/// compile error at every rendering site — which is what stops a fifth case
/// silently rendering as a grey dot.
library;

import 'package:healthee/ble/strap_progress.dart';
import 'package:healthee/data/sync/sync_failure.dart';
import 'package:meta/meta.dart';

/// The live state of the link to the strap.
@immutable
sealed class StrapConnection {
  /// Base constructor. Use one of the cases.
  const StrapConnection();

  /// Whether work is in flight, so the chrome can show motion honestly.
  bool get isBusy => switch (this) {
    Disconnected() || Connected() || ConnectionFailed() => false,
    Scanning() || Connecting() || Authenticating() || Syncing() => true,
  };
}

/// No session is open. The resting state, and the state after every unwind.
final class Disconnected extends StrapConnection {
  /// [lastCompleteSync] dates the last pull that finished in full, if any.
  const Disconnected({this.lastCompleteSync});

  /// When a sync last completed. Null on a phone that has never finished one.
  ///
  /// Carried here so the chrome can say "Synced 4 min ago" while idle. That is
  /// the useful fact and it is also the honest one: after a healthy sync the
  /// app has released the link on purpose, and reporting the socket ("Not
  /// connected") describes a normal resting state in the words of a fault.
  final DateTime? lastCompleteSync;
}

/// Listening for the strap's advertisement before trying to connect.
///
/// A real step, not a decorative one: the scan is what turns a fifteen-second
/// handshake timeout into "that strap didn't advertise in 12 seconds", which is
/// the message that tells the owner where the strap actually is.
final class Scanning extends StrapConnection {
  /// Looking for the paired strap.
  const Scanning();
}

/// The radio link is being opened. Nothing is authenticated yet.
final class Connecting extends StrapConnection {
  /// Opening the link.
  const Connecting();
}

/// The five-step handshake is in flight.
///
/// Separate from [Connecting] because the failures differ and so does the
/// remedy: a link that will not open is usually range or another app holding
/// the strap; a handshake that will not complete is usually a key that changed.
final class Authenticating extends StrapConnection {
  /// Running the handshake.
  const Authenticating();
}

/// Authenticated, and pulling data.
final class Syncing extends StrapConnection {
  /// [progress] is null between the handshake and the first fetch.
  const Syncing({this.progress});

  /// Which step of the fetch plan has started, when the fetcher has said.
  ///
  /// Nullable, and null is rendered as an indeterminate state rather than as
  /// `0 of 13`. A determinate bar that is really a guess is the thing
  /// `strap_progress.dart` exists to avoid.
  final StrapSyncProgress? progress;
}

/// An authenticated session is open **right now**.
final class Connected extends StrapConnection {
  /// [since] is when the handshake succeeded — `StrapSession.authenticatedAt`.
  const Connected({required this.since, this.batteryPercent});

  /// When this session was authenticated. Present tense, evidenced.
  final DateTime since;

  /// Strap battery, when the characteristic answered.
  final int? batteryPercent;
}

/// The attempt stopped, and here is which failure it was.
final class ConnectionFailed extends StrapConnection {
  /// [failure] keeps the original taxonomy's own words.
  const ConnectionFailed(this.failure, {this.lastCompleteSync});

  /// The named reason, with its headline and its remedy intact.
  final SyncFailure failure;

  /// When a sync last completed, so the chrome can show both halves.
  ///
  /// An unreachable strap needs two sentences, not one: *why* it is unreachable
  /// and *how stale the data therefore is*. A failure alone reads as though
  /// nothing is known; a freshness line alone hides the problem.
  final DateTime? lastCompleteSync;
}
