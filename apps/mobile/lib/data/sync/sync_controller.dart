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
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/foreground_link.dart';
import 'package:healthee/data/sync/foreground_watch.dart';
import 'package:healthee/data/sync/sync_engine.dart';
import 'package:healthee/data/sync/sync_outcome.dart';
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
    }
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
