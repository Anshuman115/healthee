/// One sync, start to finish: scan → connect → handshake → pull → store → prune.
///
/// ```text
///   strap ──BLE──▶ StrapSync ──typed models──▶ StrapWriter ──▶ SQLite ──▶ screen
/// ```
///
/// **There is no network in this path.** The engine reads the strap and keeps
/// what it read; sending it is `data/push/push_service.dart`'s job, run after
/// this one by `SyncController`. The two are separate so a server that is down
/// cannot make a good pull look failed.
///
/// ## Where it resumes, and why that is not a decision made here
///
/// The engine does not remember a cursor. It asks
/// [StrapWriter.resumeWindow] for the watermarks, which are `MAX(ts)` over the
/// rows actually on disk, per metric. So a pull that dies with four metrics
/// stored and five not resumes from exactly where its own data stopped — no
/// bookkeeping to keep in step, and no window that can be wrong in the direction
/// that skips data. The one thing this file does decide is when the two one-shot
/// backfill flags are set, and it sets them **only after a complete pull**,
/// because re-running a wide pass is cheap and skipping one leaves a permanent
/// hole (see `strap_sync.dart` for what those two holes were).
///
/// ## Two ways in, one of which owns nothing
///
/// When the app is in front, `ForegroundLink` already holds an authenticated
/// session, and a sync started then is handed that session through [SyncEngine.run]'s
/// `session` argument. On that path the engine does NOT scan, does NOT connect,
/// and — the part that matters — does NOT close: whoever opened it closes it.
/// Skipping the scan and the handshake is what makes `Sync now` near-instant
/// while the app is open, and the ownership rule is what stops a sync from
/// tearing down the link the chrome is still reporting as `Connected`.
///
/// It also changes where the run lands. With a held session the resting state is
/// `Connected`, not `Disconnected` — computed from the session's own `isOpen`
/// rather than from the fact that one was passed in, so a session that died
/// during the pull cannot leave the state claiming it.
///
/// ## What "interruptible" means, precisely
///
/// [SyncCancelToken] is checked at every phase boundary — before the scan,
/// before the connect, and after the pull returns. It is deliberately NOT
/// checked mid-round: the activity-fetch protocol has no abort, and a round
/// abandoned between its data packets and its completion reply leaves the strap
/// waiting for an ack it will never get. Cancelling after a pull still stores
/// what the pull produced, because throwing away measured data to honour a
/// button press would be the worse of the two.
library;

import 'package:healthee/ble/models/strap_sync_result.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_progress.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/ble/strap_session.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/preflight_scan.dart';
import 'package:healthee/data/sync/sync_failure.dart';
import 'package:healthee/data/sync/sync_outcome.dart';

/// A cooperative cancel flag, checked at phase boundaries.
class SyncCancelToken {
  bool _cancelled = false;

  /// Whether the owner has asked for this run to stop.
  bool get isCancelled => _cancelled;

  /// Asks the run to stop at its next phase boundary. Idempotent.
  void cancel() => _cancelled = true;
}

/// Runs one sync and reports every state it passes through.
class SyncEngine {
  /// [scanner] runs the pre-flight presence check; [client] speaks the protocol;
  /// [store] is the local 60-day tier.
  const SyncEngine({
    required this.client,
    required this.store,
    required this.scanner,
  });

  /// The protocol layer.
  final StrapClient client;

  /// The local tier this sync writes to.
  final LocalStore store;

  /// The presence check. See [_scan] for why it is worth the seconds.
  final StrapScanner scanner;

  /// Runs one sync for the owner-local [today] (`YYYY-MM-DD`).
  ///
  /// [onState] is called with every [StrapConnection] the run passes through,
  /// in order. The run always ends on a resting state — [Disconnected],
  /// [ConnectionFailed], or [Connected] when a caller-owned [session] is still
  /// open — guaranteed by the `finally` below, so a state claiming a live
  /// session cannot outlive one.
  ///
  /// [session] is an already-authenticated session the caller owns and will
  /// close. Passing one skips the scan and the handshake; passing null is the
  /// original connect → pull → disconnect run.
  Future<SyncOutcome> run({
    required String today,
    required void Function(StrapConnection state) onState,
    SyncCancelToken? cancel,
    StrapSession? session,
  }) async {
    final token = cancel ?? SyncCancelToken();
    final at = DateTime.now();
    // The net under the whole run. Every ordinary path lands through `_stamp`,
    // but a failure the protocol does not own — the database refusing a write,
    // say — would otherwise leave the chrome showing `Syncing` for a run that
    // has stopped. A UI stuck mid-progress is a lie with no author, so the
    // `finally` closes it while still letting the exception out (Standards §1:
    // failures are surfaced, never swallowed).
    var landedOnRest = false;
    void emit(StrapConnection state) {
      landedOnRest =
          state is Disconnected ||
          state is ConnectionFailed ||
          state is Connected;
      onState(state);
    }

    try {
      // Skipped when a session is already open: it IS the presence check, and
      // twelve seconds of scanning for a strap we are talking to is the delay
      // holding the link was meant to remove.
      if (session == null) {
        final blocked = await _scan(emit);
        if (blocked != null) {
          return await _stamp(at, SyncFailed(blocked), emit, session: session);
        }
      }
      if (token.isCancelled) {
        return await _stamp(
          at,
          const SyncPartial('you stopped it before it ran'),
          emit,
          session: session,
        );
      }
      return await _pull(
        today: today,
        at: at,
        onState: emit,
        token: token,
        session: session,
      );
    } on StrapException catch (error, stackTrace) {
      // Named, logged, and surfaced — never swallowed (Standards §1). Nothing
      // reached the store on this path: `StrapSync` throws before it returns a
      // result, so there is no partial write to reconcile.
      AppLog.failure('sync', 'syncing the strap', error, stackTrace);
      return await _stamp(
        at,
        SyncFailed(SyncFailure.strap(error.failure)),
        emit,
        session: session,
      );
    } finally {
      if (!landedOnRest) {
        // Deliberately without a date: the store is the thing that just failed,
        // so asking it when we last synced is the least trustworthy read
        // available. A held session that is still open is the one thing we can
        // still state, because the session itself is what answers.
        onState(_liveRest(session) ?? const Disconnected());
      }
    }
  }

  /// [Connected] when [session] is open right now, else null.
  ///
  /// Asks the session rather than the caller. A session handed in and then
  /// killed mid-pull must not leave the chrome claiming a link — and the caller
  /// has no way to know that happened, while the session does.
  static Connected? _liveRest(StrapSession? session) {
    if (session == null || !session.isOpen) {
      return null;
    }
    final since = session.authenticatedAt;
    return since == null
        ? null
        : Connected(since: since, batteryPercent: session.batteryPercent);
  }

  /// Looks for the strap before spending fifteen seconds on a handshake.
  ///
  /// The check itself lives in [PreflightScan], which the foreground link runs
  /// too; this only publishes the state around it.
  Future<SyncFailure?> _scan(void Function(StrapConnection) onState) async {
    onState(const Scanning());
    return PreflightScan(pairing: client.pairing, scanner: scanner).run();
  }

  Future<SyncOutcome> _pull({
    required String today,
    required DateTime at,
    required void Function(StrapConnection) onState,
    required SyncCancelToken token,
    required StrapSession? session,
  }) async {
    final window = await store.strapWriter.resumeWindow();
    void onProgress(StrapSyncProgress progress) =>
        onState(Syncing(progress: progress));

    final result = session != null
        // Reused, not reopened — and NOT closed here; see the library docstring
        // on who owns a session.
        ? await client.syncOver(session, window, onProgress: onProgress)
        : await client.syncOnce(
            window,
            onPhase: (phase) => onState(switch (phase) {
              StrapPhase.connecting => const Connecting(),
              StrapPhase.authenticating => const Authenticating(),
              // `StrapSession` emits this only after the strap accepted the
              // proof, and stamps `authenticatedAt` on the same line, so the
              // claim and its evidence are one fact.
              StrapPhase.authenticated => Connected(since: DateTime.now()),
            }),
            onProgress: onProgress,
          );

    final pruned = await _store(result, today);
    return _stamp(
      at,
      _outcomeFor(result, token, pruned),
      onState,
      result: result,
      session: session,
    );
  }

  /// Writes the pull, advances the one-shot flags, applies the horizon.
  Future<int> _store(StrapSyncResult result, String today) async {
    await store.strapWriter.saveSync(result);
    await store.strapWriter.stampBattery(result.batteryPercent);
    // 60 days, applied by the store's one expression of it. Run on every sync
    // rather than on a schedule: a phone that syncs is a phone whose horizon
    // moved, and a prune that needs its own trigger is a prune that stops.
    return store.pruneBeyondHorizon(today);
  }

  /// Which of the three endings this pull was.
  ///
  /// Both partial cases name something real and specific. A pull with no
  /// activity channel got the counter and nothing else; a pull with no counter
  /// is missing the one measurement that has no other home (#121) and cannot be
  /// re-read tomorrow, so it is worth saying out loud even though the rest
  /// arrived.
  SyncOutcome _outcomeFor(
    StrapSyncResult result,
    SyncCancelToken token,
    int pruned,
  ) {
    if (token.isCancelled) {
      return const SyncPartial('you stopped it part-way through');
    }
    if (!result.activityChannelPresent) {
      return const SyncPartial(
        'the strap did not offer its history channel, so only the daily '
        'counter arrived',
      );
    }
    if (result.dailyTotals == null) {
      return const SyncPartial(
        "the strap did not report its daily step counter, so today's step "
        'total is missing',
      );
    }
    return SyncComplete(storedSamples: result.samples.length, prunedRows: pruned);
  }

  /// Records the attempt and lands the state machine.
  ///
  /// The one exit. `stampAttempt` moves "last complete sync" only when
  /// [SyncOutcome.isComplete], which is where partial-is-not-complete is
  /// actually enforced; and the state ends on a resting case, so nothing can be
  /// left claiming a live session that is not there.
  Future<SyncOutcome> _stamp(
    DateTime at,
    SyncOutcome outcome,
    void Function(StrapConnection) onState, {
    required StrapSession? session,
    StrapSyncResult? result,
  }) async {
    if (outcome.isComplete && result != null) {
      await store.strapWriter.markBackfillsRan(result);
    }
    await store.strapWriter.stampAttempt(
      at: at,
      outcomeId: outcome.id,
      complete: outcome.isComplete,
    );
    AppLog.info('sync', outcome.summary);
    final lastComplete = await store.strapWriter.lastCompleteSync();
    onState(switch (outcome) {
      // A failure carries the freshness fact too: "we cannot reach the strap"
      // without "and your numbers are from this morning" is half the news.
      SyncFailed(:final failure) => ConnectionFailed(
        failure,
        lastCompleteSync: lastComplete,
      ),
      // A pull over a held session leaves it held, so `Connected` is still the
      // true statement — but only if the session says so.
      _ =>
        _liveRest(session) ?? Disconnected(lastCompleteSync: lastComplete),
    });
    return outcome;
  }
}
