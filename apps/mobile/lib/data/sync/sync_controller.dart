/// The app's live connection state, and the one way to start or stop a sync.
///
/// Thin on purpose. Everything that decides anything is in [SyncEngine]; this
/// holds the current [StrapConnection], forbids two syncs at once, and tells the
/// screen to re-read the store when one finishes. Keeping the decisions out of a
/// Riverpod notifier is what lets the engine be tested against a fake strap and
/// a real in-memory database with no container at all.
///
/// `keepAlive` because a sync outlives the screen that started it: a controller
/// disposed on navigation would drop its state mid-handshake and leave the strap
/// holding a session nobody is going to close.
library;

import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
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

  /// A phone that has just launched has no session open, and says so.
  ///
  /// Not "connected because we are paired" — that is the claim
  /// `connection_state.dart` exists to make unrepresentable. The last complete
  /// sync is read from the store by the screen that shows it, not asserted here
  /// from an unawaited guess.
  @override
  StrapConnection build() => const Disconnected();

  /// Runs one sync, publishing every state it passes through.
  ///
  /// A no-op while one is already running: the strap accepts a single
  /// connection at a time, so a second attempt would fail on the radio and
  /// report a confusing "couldn't connect" for a strap that is right there and
  /// busy talking to us.
  Future<SyncOutcome?> syncNow() async {
    if (state.isBusy) {
      return null;
    }
    final token = SyncCancelToken();
    _token = token;
    try {
      return await ref.read(syncEngineProvider).run(
        today: ref.read(todayProvider),
        onState: (next) => state = next,
        cancel: token,
      );
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
}
