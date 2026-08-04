/// The link that holds the strap while the app is in front — and lets go.
///
/// Against the same `FakeStrap` the protocol tests use, so what is exercised is
/// a real handshake over a scripted device rather than a mock of our own code.
///
/// The three claims, all asserted rather than assumed:
///
///   * **a backgrounded app holds no session** — checked on the link AND on the
///     device, because "we set our field to null" and "we hung up" are different
///     facts and only the second one gives the strap back to the Zepp app.
///   * **the backoff grows, and stops when waiting cannot help.** The schedule
///     is injected, so the delays are read off rather than waited out.
///   * **`Connected` never appears without a live session**, including for a
///     phone that holds perfectly good credentials the strap refuses.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/transport/strap_link.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/foreground_link.dart';
import 'package:healthee/data/sync/reconnect_policy.dart';
import 'package:healthee/data/sync/sync_failure.dart';

import '../ble/_fake_strap.dart';
import '../ble/strap_client_test.dart' show clientFor, healthyStrap;
import '../pairing/_pairing_fakes.dart';

const String _key = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const String _mac = 'DB:98:1F:80:4C:3D';
final DateTime _lastSync = DateTime(2026, 8, 4, 9, 12);

/// The backoff's clock, recorded instead of waited.
///
/// Every scheduled delay is kept, so a test can assert the SCHEDULE — which is
/// the actual claim ("2 s, then 6 s, then 20 s") rather than a proxy for it.
/// The returned timer is cancelled on the way out: this fake never fires on its
/// own, so nothing is left pending when a test ends.
class FakeSchedule {
  /// Every delay asked for, in order.
  final List<Duration> delays = [];

  final List<void Function()> _pending = [];

  /// The [DelayedCall] to hand the link.
  Timer call(Duration delay, void Function() action) {
    delays.add(delay);
    _pending.add(action);
    return Timer(const Duration(days: 1), () {})..cancel();
  }

  /// Runs the oldest pending retry and lets its async work settle.
  Future<void> fire() async {
    final action = _pending.removeAt(0);
    action();
    await pumpEventQueue();
  }
}

/// A link over [factory], with the schedule and the freshness fact pinned.
({ForegroundLink link, List<StrapConnection> seen, FakeSchedule clock}) linkFor(
  StrapLinkFactory factory, {
  FakeStrapScanner? scanner,
  DateTime? lastSync,
  StrapClient? client,
}) {
  final seen = <StrapConnection>[];
  final clock = FakeSchedule();
  return (
    link: ForegroundLink(
      client: client ?? clientFor(factory),
      scanner: scanner ?? FakeStrapScanner(),
      lastCompleteSync: () async => lastSync ?? _lastSync,
      onState: seen.add,
      schedule: clock.call,
      // Short and distinct, so the assertions read as a schedule rather than as
      // three numbers that happen to differ.
      policy: const ReconnectPolicy(
        delays: <Duration>[
          Duration(seconds: 2),
          Duration(seconds: 6),
          Duration(seconds: 20),
        ],
      ),
    ),
    seen: seen,
    clock: clock,
  );
}

void main() {
  group('the app in front', () {
    test('holds an authenticated session, and says so', () async {
      late FakeStrap strap;
      final wired = linkFor((_) => strap = healthyStrap());

      await wired.link.toForeground();

      expect(wired.link.held, isNotNull);
      expect(wired.link.held!.isOpen, isTrue);
      expect(wired.seen.last, isA<Connected>());
      expect(
        strap.closed,
        isFalse,
        reason: 'holding the link means not hanging up after the handshake',
      );
    });

    test('walks the phases before it claims the session', () async {
      final wired = linkFor((_) => healthyStrap());

      await wired.link.toForeground();

      expect(wired.seen.first, isA<Scanning>());
      expect(wired.seen.whereType<Connecting>(), isNotEmpty);
      expect(wired.seen.whereType<Authenticating>(), isNotEmpty);
      expect(
        wired.seen.indexWhere((s) => s is Authenticating) <
            wired.seen.indexWhere((s) => s is Connected),
        isTrue,
      );
    });

    test('a second foreground does not open a second session', () async {
      var built = 0;
      final wired = linkFor((_) {
        built++;
        return healthyStrap();
      });

      await wired.link.toForeground();
      await wired.link.toForeground();

      expect(built, 1, reason: 'the strap accepts one connection at a time');
    });
  });

  group('the app in the background', () {
    test('A BACKGROUNDED APP HOLDS NO SESSION', () async {
      late FakeStrap strap;
      final wired = linkFor((_) => strap = healthyStrap());

      await wired.link.toForeground();
      await wired.link.toBackground();

      expect(wired.link.held, isNull, reason: 'nothing is held');
      expect(wired.link.isForeground, isFalse);
      expect(
        strap.closed,
        isTrue,
        reason:
            'closed properly, not dropped — a link nobody hung up still holds '
            'the strap, and the strap accepts one connection at a time',
      );
    });

    test('it says how fresh the data is, not that a socket is shut', () async {
      final wired = linkFor((_) => healthyStrap());

      await wired.link.toForeground();
      await wired.link.toBackground();

      final resting = wired.seen.last;
      expect(resting, isA<Disconnected>());
      expect((resting as Disconnected).lastCompleteSync, _lastSync);
    });

    test('it stops trying, and does not re-open one behind the app', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
      );

      await wired.link.toForeground();
      expect(wired.clock.delays, hasLength(1));
      await wired.link.toBackground();
      await wired.clock.fire();

      expect(
        wired.link.held,
        isNull,
        reason: 'a retry that fires after backgrounding must find nobody home',
      );
      expect(wired.seen.whereType<Connected>(), isEmpty);
    });
  });

  group('the backoff', () {
    test('grows for a failure a wait could clear', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
      );

      await wired.link.toForeground();
      await wired.clock.fire();
      await wired.clock.fire();

      expect(wired.clock.delays, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 6),
        const Duration(seconds: 20),
      ]);
    });

    test('holds at the last delay rather than giving up', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
      );

      await wired.link.toForeground();
      for (var i = 0; i < 4; i++) {
        await wired.clock.fire();
      }

      expect(wired.clock.delays.last, const Duration(seconds: 20));
      expect(
        wired.clock.delays,
        hasLength(5),
        reason: 'still trying, because a strap that comes back should reconnect',
      );
    });

    test('A PERMANENT FAILURE STOPS RETRYING — Bluetooth is off', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const BluetoothOff()),
      );

      await wired.link.toForeground();

      expect((wired.seen.last as ConnectionFailed).failure.code, 'bluetooth_off');
      expect(
        wired.clock.delays,
        isEmpty,
        reason: 'a tight loop against a switched-off radio is a battery bug',
      );
    });

    test('a refused permission stops retrying too', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(
          failure: const BluetoothPermissionDenied(permanently: true),
        ),
      );

      await wired.link.toForeground();

      expect(wired.clock.delays, isEmpty);
    });

    test('a key the strap rejects stops retrying — re-pairing is the only way', () async {
      final wired = linkFor(
        (_) => FakeStrap(authKey: parseAuthKey(_key), rejectAuthKey: true),
      );

      await wired.link.toForeground();

      expect((wired.seen.last as ConnectionFailed).failure.code, 'handshake_refused');
      expect(wired.clock.delays, isEmpty);
    });

    test('a failure carries the freshness fact as well as the reason', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const BluetoothOff()),
      );

      await wired.link.toForeground();

      expect((wired.seen.last as ConnectionFailed).lastCompleteSync, _lastSync);
    });
  });

  group('somebody else is holding the strap', () {
    test('says THAT, rather than blaming a band on the wrist', () async {
      final scanner = FakeStrapScanner(
        failure: const StrapNotInRange(seconds: 12),
        connectedElsewhere: true,
      );
      final wired = linkFor((_) => healthyStrap(), scanner: scanner);

      await wired.link.toForeground();

      final failure = (wired.seen.last as ConnectionFailed).failure;
      expect(failure.code, 'strap_held_elsewhere');
      expect(failure.remedy, contains('Zepp'));
      expect(scanner.askedWhoHolds, <String>[_mac]);
    });

    test('and stops retrying, because only the owner can release it', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(
          failure: const StrapNotInRange(seconds: 12),
          connectedElsewhere: true,
        ),
      );

      await wired.link.toForeground();

      expect(wired.clock.delays, isEmpty);
    });

    test('no evidence keeps the not-in-range words', () async {
      final wired = linkFor(
        (_) => healthyStrap(),
        scanner: FakeStrapScanner(failure: const StrapNotInRange(seconds: 12)),
      );

      await wired.link.toForeground();

      expect(
        (wired.seen.last as ConnectionFailed).failure.code,
        'strap_not_in_range',
        reason: 'a suspicion is not upgraded into a certainty',
      );
    });
  });

  group('a sync failed over the held session', () {
    test('the session is let go rather than kept behind a failure', () async {
      late FakeStrap strap;
      final wired = linkFor((_) => strap = healthyStrap());
      await wired.link.toForeground();

      await wired.link.invalidate(
        SyncFailure.strap(const StrapUnreachable('it stopped answering')),
      );

      expect(wired.link.held, isNull);
      expect(strap.closed, isTrue);
      expect(
        wired.clock.delays,
        <Duration>[const Duration(seconds: 2)],
        reason: 'a transient failure earns another go, after a readable pause',
      );
    });

    test('and a permanent one earns no retry at all', () async {
      final wired = linkFor((_) => healthyStrap());
      await wired.link.toForeground();

      await wired.link.invalidate(SyncFailure.pairing(const BluetoothOff()));

      expect(wired.link.held, isNull);
      expect(wired.clock.delays, isEmpty);
    });
  });

  group('"connected" is a claim about the present', () {
    test('A REFUSED KEY NEVER YIELDS "CONNECTED"', () async {
      final wired = linkFor(
        (_) => FakeStrap(authKey: parseAuthKey(_key), rejectAuthKey: true),
      );

      await wired.link.toForeground();

      expect(
        wired.seen.whereType<Connected>(),
        isEmpty,
        reason: 'holding credentials is not being connected',
      );
      expect(wired.link.held, isNull);
    });

    test('a closed session stops answering `held`, without a flag', () async {
      final wired = linkFor((_) => healthyStrap());
      await wired.link.toForeground();
      final session = wired.link.held!;

      await session.close();

      expect(
        wired.link.held,
        isNull,
        reason: 'the session is asked, never remembered',
      );
    });
  });
}
