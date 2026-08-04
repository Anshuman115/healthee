/// Whether the app may start a sync **nobody asked for**, and why not when not.
///
/// The owner should never have to press "Sync now". They still can — an explicit
/// request is not a heuristic and is never debounced — but the button existing is
/// not the same as the button being required.
///
/// ## The window, and why the stamp has to be on disk
///
/// An automatic sync on every foreground is not automatic syncing, it is a sync
/// on every glance: the app is opened many times an hour and each open would pay
/// a full BLE fetch plan for seconds of new data. So one runs only when the last
/// **successful** sync is older than [kAutoSyncWindow].
///
/// The instant it compares against is `SyncKeys.lastCompleteSyncMs`, in SQLite —
/// **the same key `StrapWriter.stampAttempt` already writes and the connection
/// strip already reads.** Two reasons, and the second is the whole point of this
/// paragraph:
///
///   1. ONE definition of "when did we last sync successfully". A second field
///      here could disagree with the one the chrome shows, and then the app
///      would be debouncing against a fact the owner cannot see.
///   2. **An in-memory stamp resets on every cold start**, which is precisely
///      how "automatic, at most every fifteen minutes" quietly becomes "on every
///      launch" — the debounce would be defeated by the one event that happens
///      most often, and it would look like it was working the entire time.
///
/// Only a *complete* sync moves that key (`sync_outcome.dart` explains why), so
/// a run that failed or half-finished does not buy fifteen minutes of silence.
/// The owner coming back to a phone whose last sync failed gets another attempt,
/// which is the direction to be wrong in.
///
/// ## What it deliberately does not do
///
/// It does not schedule anything. There is no timer, no periodic job and no
/// background execution: Android restricts background BLE hard, the strap
/// buffers on-device, and a sync that happens while the app is open is the
/// honest trade. This gate is asked a question on a foreground transition and
/// answers it; nothing here can fire on its own.
library;

import 'package:meta/meta.dart';

/// How stale the last complete sync must be before one starts unasked.
///
/// Fifteen minutes is a compromise between two costs that pull opposite ways: a
/// BLE fetch plan is seconds of radio on both devices, and the strap's own
/// buffer means nothing is lost by waiting. Short enough that a screen looked at
/// twice in an afternoon is current; long enough that opening the app four times
/// in five minutes opens the radio once.
const Duration kAutoSyncWindow = Duration(minutes: 15);

/// Why an automatic sync did or did not start.
///
/// A named answer rather than a bool, because every one of these is a different
/// thing to log and three of them are perfectly healthy. "It did not sync" with
/// no reason attached is the shape of a bug nobody can find later.
enum AutoSyncDecision {
  /// Go: the link is held, nothing is running, and the window has passed.
  start,

  /// No session is held, so there is nothing to sync over. The connection strip
  /// is already saying why, in its own words.
  noLink,

  /// A sync or a connection attempt is already running. Standards §1: a second
  /// attempt fails on the radio and reports a confusing error for a strap that
  /// is right there and busy talking to us.
  busy,

  /// A successful sync is more recent than [kAutoSyncWindow].
  tooSoon;

  /// Whether a sync should be started. One place, so no caller re-derives it.
  bool get shouldStart => this == AutoSyncDecision.start;
}

/// Decides whether to start a sync the owner did not ask for.
///
/// Pure with respect to everything except [lastCompleteSync] and [now], both
/// injected, so the window can be tested at its exact boundary rather than
/// waited out.
@immutable
class AutoSyncGate {
  /// [lastCompleteSync] reads the persisted stamp; [now] is the clock.
  const AutoSyncGate({
    required this.lastCompleteSync,
    required this.now,
    this.window = kAutoSyncWindow,
  });

  /// When a sync last finished completely, or null if none ever has.
  ///
  /// A function rather than a value: it is read at the moment the decision is
  /// made, never cached. A window compared against a timestamp captured minutes
  /// ago is the stale-as-current failure this product exists against.
  final Future<DateTime?> Function() lastCompleteSync;

  /// The clock. Injected so a test does not sleep for fifteen minutes.
  final DateTime Function() now;

  /// How stale the last complete sync must be.
  final Duration window;

  /// The answer, given what the link and the controller currently are.
  ///
  /// A phone that has never synced returns [AutoSyncDecision.start]: there is no
  /// stamp to be inside the window of, and the first sync is the one most worth
  /// not making the owner ask for.
  Future<AutoSyncDecision> decide({
    required bool linkHeld,
    required bool busy,
  }) async {
    if (busy) {
      return AutoSyncDecision.busy;
    }
    if (!linkHeld) {
      return AutoSyncDecision.noLink;
    }
    final last = await lastCompleteSync();
    if (last == null) {
      return AutoSyncDecision.start;
    }
    // Strictly greater: at exactly the window the previous sync is still inside
    // it. Chosen so the boundary has one meaning and a test can pin it.
    final since = now().difference(last);
    return since > window ? AutoSyncDecision.start : AutoSyncDecision.tooSoon;
  }
}
