/// The app's live connection state, and the one way to start or stop a sync.
///
/// Thin on purpose. Everything that decides anything is in [SyncEngine] and
/// [ForegroundLink]; this holds the current [StrapConnection], forbids two syncs
/// at once, wires the lifecycle to the link, and tells the screen to re-read the
/// store when a sync finishes. Keeping the decisions out of a Riverpod notifier
/// is what lets both be tested against a fake strap and a real in-memory
/// database with no container at all.
///
/// `keepAlive` for two reasons now. A sync outlives the screen that started it —
/// a controller disposed on navigation would drop its state mid-handshake and
/// leave the strap holding a session nobody is going to close. And the held
/// foreground link is an app-level fact, not a screen-level one: tying it to a
/// widget would release the strap on every navigation.
///
/// ## One owner of the state, two producers
///
/// [ForegroundLink] publishes while it is opening or holding a session;
/// [SyncEngine] publishes while a pull is running. They cannot overlap: a sync
/// is refused while [StrapConnection.isBusy], and the link never opens a second
/// session while it holds one. When a sync over the held session fails, the
/// session is invalidated rather than kept — the state has just said the link
/// failed, and continuing to hold a session behind that would be the two
/// disagreeing.
library;

import 'dart:async';

import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/push/push_outcome.dart';
import 'package:healthee/data/push/push_service.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/foreground_link.dart';
import 'package:healthee/data/sync/foreground_watch.dart';
import 'package:healthee/data/sync/sync_engine.dart';
import 'package:healthee/data/sync/sync_outcome.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_controller.g.dart';

/// The app's sync engine, wired to the one client, store and scanner.
@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) => SyncEngine(
  client: ref.watch(strapClientProvider),
  store: ref.watch(localStoreProvider),
  scanner: ref.watch(strapScannerProvider),
);

/// Holds what the link to the strap is doing, and drives it.
@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  SyncCancelToken? _token;
  ForegroundLink? _link;

  /// A phone that has just launched has no session open, and says so.
  ///
  /// Not "connected because we are paired" — that is the claim
  /// `connection_state.dart` exists to make unrepresentable. The link is asked
  /// to open one immediately afterwards, and publishes the truth as it goes.
  @override
  StrapConnection build() {
    final link = ForegroundLink(
      client: ref.watch(strapClientProvider),
      scanner: ref.watch(strapScannerProvider),
      lastCompleteSync: ref.watch(localStoreProvider).strapWriter.lastCompleteSync,
      onState: (next) => state = next,
    );
    final watch = ForegroundWatch(
      onForeground: () => unawaited(link.toForeground()),
      onBackground: () => unawaited(link.toBackground()),
    );
    _link = link;
    ref.onDispose(() {
      watch.dispose();
      unawaited(link.dispose());
    });
    // Deferred by a microtask, not called here: [ForegroundWatch.start] reports
    // the state the app is already in, and that report sets `state` — which a
    // notifier may not do from inside its own `build`.
    scheduleMicrotask(watch.start);
    return const Disconnected();
  }

  /// Runs one sync, publishing every state it passes through.
  ///
  /// A no-op while one is already running: the strap accepts a single
  /// connection at a time, so a second attempt would fail on the radio and
  /// report a confusing "couldn't connect" for a strap that is right there and
  /// busy talking to us.
  ///
  /// Near-instant while the app is in front, because the held session skips
  /// both the twelve-second scan and the handshake.
  ///
  /// ## The push runs after, and cannot undo the pull
  ///
  /// A sync now has two halves — read the strap, then send what is stored — and
  /// they are deliberately not one operation. The pull's success is already
  /// recorded by the time the push starts, so a server that is down cannot make
  /// a good sync look failed, and the measurements are on disk either way. The
  /// push reports itself through its own health surface (`PushStamp`), which is
  /// where a background failure belongs (Standards §1).
  Future<SyncOutcome?> syncNow() async {
    if (state.isBusy) {
      return null;
    }
    final token = SyncCancelToken();
    _token = token;
    final link = _link;
    try {
      final outcome = await ref.read(syncEngineProvider).run(
        today: ref.read(todayProvider),
        onState: (next) => state = next,
        cancel: token,
        session: link?.held,
      );
      if (outcome is SyncFailed && link != null) {
        // The session we were handed did not carry a sync. Keeping it would
        // mean the chrome showing a failure over a link we still claim.
        await link.invalidate(outcome.failure);
      }
      return outcome;
    } finally {
      _token = null;
      // Whatever happened, the store may have moved. Re-reading is cheap and
      // reading stale is the failure this app is built against.
      ref.invalidate(deviceDayProvider);
      await pushNow();
    }
  }

  /// Sends everything the local tier is holding back, then re-reads Today.
  ///
  /// Separate from [syncNow] and callable on its own, because the two fail
  /// independently: a phone with no Bluetooth but a good network should still
  /// clear its backlog, and a phone with a strap in range but no signal should
  /// still store what it reads.
  ///
  /// Returns the outcome so a caller can show it; it is stamped into the store
  /// regardless, so a caller that ignores it still leaves the health surface
  /// truthful.
  Future<PushOutcome> pushNow() async {
    final outcome = await ref.read(pushServiceProvider).run();
    if (outcome.rowsSent > 0) {
      // The server has new measurements, so its derived numbers have moved.
      // Invalidating only when something was actually sent keeps a failed push
      // from re-fetching a payload that cannot have changed.
      ref.invalidate(todaySnapshotProvider);
    }
    return outcome;
  }

  /// Asks the running sync to stop at its next phase boundary.
  ///
  /// Not an abort. `sync_engine.dart` says why the activity-fetch rounds cannot
  /// be interrupted mid-flight, and what is kept when a run is stopped.
  void cancel() => _token?.cancel();

  /// The session held for the foreground, or null. For tests and for the strip.
  ///
  /// Exposed so `a backgrounded app holds no session` can be ASSERTED rather
  /// than assumed — the one claim in this feature that cannot be checked from
  /// the outside.
  bool get holdsSession => _link?.held != null;
}
