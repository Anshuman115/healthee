/// Automatic sync, wired: real lifecycle → real controller → real handshake.
///
/// `auto_sync_test.dart` proves the gate's arithmetic against a real store.
/// This proves anything ever asks it — the part no unit test can reach. What is
/// driven here is the platform's own `AppLifecycleState`, through the binding,
/// exactly as `foreground_lifecycle_test.dart` drives it; the peer is
/// `FakeStrap` and the store is a real in-memory SQLite.
///
/// A sync is counted by transitions INTO [Syncing] from something that is not
/// [Syncing]. The engine publishes `Syncing` many times per run as the fetch
/// plan advances, so counting the states themselves would count progress
/// reports; counting the edges counts syncs.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/push/push_service.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/auto_sync.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';

import '../ble/strap_client_test.dart' show clientFor, healthyStrap, stressRounds;
import '../pairing/_pairing_fakes.dart';
import '../push/_push_fakes.dart';

const String _today = '2026-08-04';
final DateTime _launch = DateTime(2026, 8, 4, 9);

void main() {
  late TestWidgetsFlutterBinding binding;
  late ProviderContainer container;
  late LocalStore store;
  late DateTime clock;
  late int syncs;

  setUpAll(() => binding = TestWidgetsFlutterBinding.ensureInitialized());

  /// Builds the controller's world and counts sync episodes.
  Future<void> wire() async {
    store = LocalStore.memory();
    clock = _launch;
    syncs = 0;
    container = ProviderContainer(
      overrides: [
        strapClientProvider.overrideWithValue(
          clientFor((_) => healthyStrap(rounds: stressRounds())),
        ),
        strapScannerProvider.overrideWithValue(FakeStrapScanner()),
        localStoreProvider.overrideWithValue(store),
        todayProvider.overrideWithValue(_today),
        syncClockProvider.overrideWithValue(() => clock),
        // A signed-out push: the point here is the PULL, and a real keystore
        // read would reach a platform channel no test host has.
        pushServiceProvider.overrideWithValue(
          PushService(
            store: store,
            client: clientOver(FakeIngestTransport()),
            credentials: signedOut(),
          ),
        ),
      ],
    );
    container.listen<StrapConnection>(syncControllerProvider, (previous, next) {
      if (next is Syncing && previous is! Syncing) {
        syncs++;
      }
    }, fireImmediately: true);
    await pumpEventQueue();
  }

  /// Moves the gate's clock to [after] past the sync the store actually
  /// recorded.
  ///
  /// Anchored to the stamp rather than to [_launch] because the engine stamps
  /// with the real wall clock, and a fake clock set relative to a fixed literal
  /// would be some unknown distance from it — a test that passed or failed on
  /// what time of day the suite ran.
  Future<void> clockTo(Duration after) async {
    final stamped = await store.strapWriter.lastCompleteSync();
    expect(stamped, isNotNull, reason: 'nothing to measure the window from');
    clock = stamped!.add(after);
  }

  /// The sequence Android sends when the owner leaves, then comes back.
  Future<void> leaveAndReturn() async {
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await pumpEventQueue();
  }

  tearDown(() async {
    await store.close();
    container.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('COMING TO THE FRONT SYNCS, WITHOUT ANYBODY ASKING', () async {
    await wire();

    expect(syncs, 1, reason: 'the owner never has to press Sync now');
    expect(
      await store.strapWriter.lastCompleteSync(),
      isNotNull,
      reason: 'and it was a real sync, which stamped a real key',
    );
  });

  test('A SECOND FOREGROUND INSIDE THE WINDOW DOES NOT SYNC AGAIN', () async {
    await wire();
    await clockTo(const Duration(minutes: 5));

    await leaveAndReturn();

    expect(
      syncs,
      1,
      reason: 'the app is opened many times an hour; each open must not pay a '
          'full fetch plan for seconds of new data',
    );
  });

  test('and one AFTER the window does', () async {
    await wire();
    await clockTo(kAutoSyncWindow + const Duration(minutes: 1));

    await leaveAndReturn();

    expect(syncs, 2);
  });

  test('A MANUAL SYNC IS NEVER DEBOUNCED', () async {
    await wire();
    // Immediately after the automatic one — the worst case for the button.
    await clockTo(const Duration(seconds: 1));

    await container.read(syncControllerProvider.notifier).syncNow();

    expect(
      syncs,
      2,
      reason: 'a button that silently declines because a heuristic says it is '
          'too soon is a button the owner learns not to trust',
    );
  });

  test('TWO SYNCS NEVER OVERLAP, even in the gap before the state says busy',
      () async {
    // The strap accepts one connection at a time, and the busy state is
    // published by the engine — so there is a window between calling `syncNow`
    // and anything reading `isBusy` being told. Both requests are made without
    // awaiting either, which is exactly the shape of a foreground transition
    // landing beside a pull-to-refresh.
    await wire();
    final controller = container.read(syncControllerProvider.notifier);
    await clockTo(const Duration(hours: 2));

    final manual = controller.syncNow();
    final auto = controller.autoSyncNow();

    expect(await auto, isNull, reason: 'refused while one is already in flight');
    expect(await manual, isNotNull, reason: 'and the first one still ran');
    expect(syncs, 2, reason: 'the launch sync and the manual one — not three');
  });

  test('and the next one after it is not blocked by a stale guard', () async {
    await wire();
    final controller = container.read(syncControllerProvider.notifier);

    await controller.syncNow();
    await controller.syncNow();

    expect(syncs, 3, reason: 'the in-flight token is cleared in a finally');
  });
}
