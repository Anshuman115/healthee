/// The wiring itself: real app lifecycle → real controller → real handshake.
///
/// `foreground_link_test.dart` drives the link by calling `toForeground` and
/// `toBackground` directly, which proves what the link does but not that
/// anything ever calls it. This drives the platform's own lifecycle through the
/// binding, so what is under test is `ForegroundWatch`'s `AppLifecycleListener`
/// — including the part no unit test can reach: that a controller built while
/// the app is ALREADY resumed opens a session, rather than waiting for a
/// transition that has already happened.
///
/// ## The transitions are sent in full, because the platform sends them in full
///
/// `AppLifecycleListener` asserts on a jump (resumed → paused is an invalid
/// transition; Android sends inactive, then hidden, then paused). Writing the
/// whole sequence here is not ceremony: it is exactly what proves that hooking
/// `onPause` rather than `onInactive` survives the intermediate states, which is
/// the difference between releasing the strap when the owner leaves and
/// releasing it every time a notification shade comes down.
///
/// The peer is `FakeStrap`, the store is a real in-memory SQLite, and nothing
/// here mocks our own code.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_scanner.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';

import '../ble/_fake_strap.dart';
import '../ble/strap_client_test.dart' show clientFor, healthyStrap;
import '../pairing/_pairing_fakes.dart';

const String _key = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const String _today = '2026-08-04';

void main() {
  late TestWidgetsFlutterBinding binding;
  late FakeStrap strap;
  late ProviderContainer container;
  late List<StrapConnection> seen;

  setUpAll(() => binding = TestWidgetsFlutterBinding.ensureInitialized());

  /// Builds the controller's world around [build], and records every state.
  Future<void> wire(FakeStrap Function() build) async {
    container = ProviderContainer(
      overrides: [
        strapClientProvider.overrideWithValue(clientFor((_) => build())),
        strapScannerProvider.overrideWithValue(FakeStrapScanner()),
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        todayProvider.overrideWithValue(_today),
      ],
    );
    seen = <StrapConnection>[];
    container.listen<StrapConnection>(
      syncControllerProvider,
      (previous, next) => seen.add(next),
      fireImmediately: true,
    );
    await pumpEventQueue();
  }

  /// The sequence Android actually sends when the owner leaves the app.
  Future<void> leave() async {
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await pumpEventQueue();
  }

  /// And the sequence it sends when they come back.
  Future<void> returnToFront() async {
    for (final state in const <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await pumpEventQueue();
  }

  tearDown(() async {
    await container.read(localStoreProvider).close();
    container.dispose();
    // Leave the binding where the next test expects to find it.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('an app already in front opens a session without a transition', () async {
    await wire(() => strap = healthyStrap());

    expect(container.read(syncControllerProvider), isA<Connected>());
    expect(container.read(syncControllerProvider.notifier).holdsSession, isTrue);
  });

  test('BACKGROUNDING RELEASES THE STRAP', () async {
    await wire(() => strap = healthyStrap());

    await leave();

    expect(
      container.read(syncControllerProvider.notifier).holdsSession,
      isFalse,
      reason: 'a link held while nobody is looking locks the owner out of Zepp',
    );
    expect(strap.closed, isTrue, reason: 'hung up, not dropped');
    expect(container.read(syncControllerProvider), isA<Disconnected>());
  });

  test('a transient inactive does NOT drop the session', () async {
    await wire(() => strap = healthyStrap());

    // A pulled-down notification shade, or the app switcher. Releasing here
    // means reconnecting seconds later, twice, for nothing.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pumpEventQueue();

    expect(container.read(syncControllerProvider.notifier).holdsSession, isTrue);
    expect(strap.closed, isFalse);
  });

  test('coming back to the front opens a new one', () async {
    var built = 0;
    await wire(() {
      built++;
      return strap = healthyStrap();
    });

    await leave();
    await returnToFront();

    expect(built, 2);
    expect(container.read(syncControllerProvider), isA<Connected>());
    expect(container.read(syncControllerProvider.notifier).holdsSession, isTrue);
  });

  test('"CONNECTED" NEVER APPEARS FROM CREDENTIALS ALONE', () async {
    // The phone holds a perfectly good MAC and key. The strap refuses them.
    await wire(
      () => strap = FakeStrap(authKey: parseAuthKey(_key), rejectAuthKey: true),
    );

    expect(
      seen.whereType<Connected>(),
      isEmpty,
      reason: 'being paired is not being connected',
    );
    expect(container.read(syncControllerProvider.notifier).holdsSession, isFalse);
    expect(container.read(syncControllerProvider), isA<ConnectionFailed>());
  });
}
