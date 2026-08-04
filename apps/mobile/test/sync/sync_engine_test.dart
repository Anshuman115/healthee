/// The engine end to end, against a scripted strap and a real in-memory store.
///
/// No mocks of our own code: the peer is `FakeStrap`, which answers the
/// handshake from the protocol document, and the store is a genuine SQLite
/// database. What is under test is therefore the whole path the brief describes
/// — strap → BLE pull → typed models → drift — rather than the seams between
/// three doubles.
///
/// The two claims worth stating plainly, both asserted below:
///
///   * **`Connected` cannot appear without a live authenticated session.** A
///     strap that refuses the key is run through the whole engine and the
///     transcript is checked for the case's absence.
///   * **a partial pull is not recorded as complete.** A strap with no history
///     channel, and one that never answers the daily counter, both land on
///     `SyncPartial` and leave `last_complete_sync` untouched.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/transport/strap_link.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_engine.dart';
import 'package:healthee/data/sync/sync_outcome.dart';

import '../ble/_fake_strap.dart';
import '../ble/strap_client_test.dart'
    show clientFor, healthyStrap, repositoryWith, stressRounds;
import '../pairing/_pairing_fakes.dart';

const String _today = '2026-08-04';

/// An engine wired to [factory], with a fresh store and a scanner that sees it.
({SyncEngine engine, LocalStore store}) engineFor(
  StrapLinkFactory factory, {
  FakeStrapScanner? scanner,
  StrapClient? client,
}) {
  final store = LocalStore.memory();
  return (
    engine: SyncEngine(
      client: client ?? clientFor(factory),
      store: store,
      scanner: scanner ?? FakeStrapScanner(),
    ),
    store: store,
  );
}

void main() {
  group('a good sync', () {
    test('stores what it pulled and reports it complete', () async {
      final wired = engineFor((_) => healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect(outcome, isA<SyncComplete>());
      expect((outcome as SyncComplete).storedSamples, 3);
      final rows = await wired.store.select(wired.store.strapSamples).get();
      expect(rows.map((row) => row.value).toList(), [40, 41, 43]);
    });

    test('THE DAILY COUNTER SURVIVES the whole path onto disk', () async {
      // The end-to-end form of the store's own test: the counter comes off the
      // radio ENCRYPTED, through the sync, into SQLite. #121 is the reason this
      // is asserted at every layer rather than once.
      final wired = engineFor((_) => healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);

      await wired.engine.run(today: _today, onState: (_) {});

      final totals = (await wired.store.select(wired.store.deviceTotals).get()).single;
      expect(totals.steps, 9264);
      expect(totals.distanceM, 6710);
    });

    test('the battery reaches the store, so the device card can show it', () async {
      final wired = engineFor((_) => healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);

      await wired.engine.run(today: _today, onState: (_) {});

      final day = await wired.store.strapReader.day(_today);
      expect(day.batteryPercent, 71);
    });

    test('it resumes from the rows on disk, not from a remembered cursor', () async {
      late FakeStrap strap;
      final wired = engineFor((_) => strap = healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);

      await wired.engine.run(today: _today, onState: (_) {});
      final firstAsk = strap.firstRequestFor(0x13);
      await wired.engine.run(today: _today, onState: (_) {});

      // The second run's stress window starts after the newest stored sample,
      // which is what "resumable" means when nothing remembers a cursor.
      final asks = strap.requestedSince
          .asMap()
          .entries
          .where((entry) => strap.requestedCodes[entry.key] == 0x13)
          .map((entry) => entry.value)
          .toList();
      expect(asks.length, greaterThan(1));
      expect(asks.last.isAfter(firstAsk!), isTrue);
    });
  });

  group('partial is not complete', () {
    test('no history channel is partial, and says which half arrived', () async {
      final wired = engineFor((_) => healthyStrap(hasActivityChannel: false));
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect(outcome, isA<SyncPartial>());
      expect((outcome as SyncPartial).reason, contains('history channel'));
      // The counter still landed — it is requested before the channel check
      // precisely so a strap that can report it does.
      expect(
        await wired.store.select(wired.store.deviceTotals).get(),
        hasLength(1),
      );
    });

    test('A PARTIAL PULL NEVER LOOKS UP TO DATE', () async {
      final wired = engineFor((_) => healthyStrap(hasActivityChannel: false));
      addTearDown(wired.store.close);

      await wired.engine.run(today: _today, onState: (_) {});

      final day = await wired.store.strapReader.day(_today);
      expect(
        day.sync.lastCompleteSync,
        isNull,
        reason: 'only a complete pull may move the timestamp the screen reads',
      );
      expect(day.sync.lastAttempt, isNotNull, reason: 'the attempt still happened');
      expect(day.sync.lastAttemptIncomplete, isTrue);
    });

    test('a strap that never answers the counter is partial too', () async {
      final wired = engineFor(
        (_) => FakeStrap(authKey: parseAuthKey(_key), rounds: stressRounds()),
      );
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect(outcome, isA<SyncPartial>());
      expect((outcome as SyncPartial).reason, contains('daily step counter'));
    });

    test('a partial pull does not set the one-shot backfill flags', () async {
      final wired = engineFor((_) => healthyStrap(hasActivityChannel: false));
      addTearDown(wired.store.close);

      await wired.engine.run(today: _today, onState: (_) {});

      final window = await wired.store.strapWriter.resumeWindow();
      expect(window.stressBackfillDone, isFalse);
      expect(
        window.napBackfillDone,
        isFalse,
        reason: 'a flag set for a pass that did not finish closes a live gap',
      );
    });

    test('cancelling before the pull stores nothing and says who stopped it', () async {
      final wired = engineFor((_) => healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);
      final token = SyncCancelToken()..cancel();

      final outcome = await wired.engine.run(
        today: _today,
        onState: (_) {},
        cancel: token,
      );

      expect(outcome, isA<SyncPartial>());
      expect((outcome as SyncPartial).reason, contains('you stopped it'));
      expect(await wired.store.select(wired.store.strapSamples).get(), isEmpty);
    });
  });

  group('failures keep their own words', () {
    test('a wrong key fails as a wrong key, with its remedy intact', () async {
      final wired = engineFor(
        (_) => FakeStrap(authKey: parseAuthKey(_key), rejectAuthKey: true),
      );
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect(outcome, isA<SyncFailed>());
      final failure = (outcome as SyncFailed).failure;
      expect(failure.code, 'handshake_refused');
      expect(failure.remedy, contains('Pair it here again'));
    });

    test('an out-of-range strap says so, instead of timing out mid-handshake', () async {
      // The whole point of the pre-flight scan: without it this is "went quiet
      // mid-handshake (15 s)", which sends the owner to look at the wrong thing.
      final wired = engineFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
      );
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect(outcome, isA<SyncFailed>());
      expect((outcome as SyncFailed).failure.code, 'strap_not_in_range');
    });

    test('Bluetooth being off keeps the radio taxonomy, not the protocol one', () async {
      final wired = engineFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const BluetoothOff()),
      );
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect((outcome as SyncFailed).failure.code, 'bluetooth_off');
      expect(outcome.failure.source, isA<BluetoothOff>());
    });

    test('an unpaired phone is not a connection failure', () async {
      final wired = engineFor(
        (_) => healthyStrap(),
        client: clientFor((_) => healthyStrap(), pairing: repositoryWith()),
      );
      addTearDown(wired.store.close);

      final outcome = await wired.engine.run(today: _today, onState: (_) {});

      expect((outcome as SyncFailed).failure.code, 'strap_not_paired');
    });
  });

  group('the connection transcript', () {
    test('walks the real phases in order and lands at rest', () async {
      final wired = engineFor((_) => healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);
      final seen = <StrapConnection>[];

      await wired.engine.run(today: _today, onState: seen.add);

      expect(seen.first, isA<Scanning>());
      expect(seen.whereType<Connecting>(), isNotEmpty);
      expect(seen.whereType<Authenticating>(), isNotEmpty);
      expect(seen.whereType<Connected>(), isNotEmpty);
      expect(seen.whereType<Syncing>(), isNotEmpty);
      expect(
        seen.last,
        isA<Disconnected>(),
        reason: 'the session closed, so the state must not still claim one',
      );
      // Ordered, not merely present: authenticating cannot precede connecting.
      expect(
        seen.indexWhere((s) => s is Connecting) <
            seen.indexWhere((s) => s is Authenticating),
        isTrue,
      );
      expect(
        seen.indexWhere((s) => s is Authenticating) <
            seen.indexWhere((s) => s is Connected),
        isTrue,
      );
    });

    test('"CONNECTED" NEVER APPEARS WITHOUT A LIVE SESSION — refused key', () async {
      final wired = engineFor(
        (_) => FakeStrap(authKey: parseAuthKey(_key), rejectAuthKey: true),
      );
      addTearDown(wired.store.close);
      final seen = <StrapConnection>[];

      await wired.engine.run(today: _today, onState: seen.add);

      expect(seen.whereType<Authenticating>(), isNotEmpty);
      expect(
        seen.whereType<Connected>(),
        isEmpty,
        reason: 'holding credentials is not being connected',
      );
      expect(seen.last, isA<ConnectionFailed>());
    });

    test('"connected" never appears when the strap is out of range', () async {
      final wired = engineFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
      );
      addTearDown(wired.store.close);
      final seen = <StrapConnection>[];

      await wired.engine.run(today: _today, onState: seen.add);

      expect(seen.whereType<Connected>(), isEmpty);
      expect(seen.whereType<Connecting>(), isEmpty);
      expect(seen.last, isA<ConnectionFailed>());
    });

    test('progress reports steps the fetcher actually started', () async {
      final wired = engineFor((_) => healthyStrap(rounds: stressRounds()));
      addTearDown(wired.store.close);
      final seen = <StrapConnection>[];

      await wired.engine.run(today: _today, onState: seen.add);

      final steps = seen.whereType<Syncing>().map((s) => s.progress!).toList();
      expect(steps.first.step, 1);
      expect(steps.first.label, 'daily step counter');
      expect(steps.last.label, 'workouts');
      expect(steps.last.step, steps.last.total);
      expect(
        steps.map((s) => s.step).toList(),
        List<int>.generate(steps.length, (i) => i + 1),
        reason: 'every step is reported once, in order — no invented ticks',
      );
    });
  });
}

const String _key = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
