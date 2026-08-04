/// The whole layer, end to end: paired credentials → connect → handshake →
/// fetch → typed models.
///
/// The peer is [FakeStrap], whose device half is written from the protocol
/// document (see its own header). What this file adds on top of the unit tests
/// is the part no unit test can reach: that the credentials come out of the
/// KEYSTORE, that a session is always closed, and that the strap's daily-total
/// counter survives all the way to the result.
///
/// The two timeouts are shortened here. They are the production values in
/// `strap_session.dart`; a suite that waits fifteen real seconds for a
/// deliberate timeout is a suite people stop running.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/models/strap_sync_window.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/ble/strap_sync.dart';
import 'package:healthee/ble/transport/strap_link.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/pairing/zepp_client.dart';

import '../pairing/_pairing_fakes.dart';
import '_fake_strap.dart';

const String _mac = 'DB:98:1F:80:4C:3D';
const String _authKey = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// A repository whose keystore holds [mac] and [authKey], or nothing.
PairingRepository repositoryWith({String? mac, String? authKey}) {
  final store = FakeSecretStore();
  if (mac != null) store.values['strap_mac'] = mac;
  if (authKey != null) store.values['strap_auth_key'] = authKey;
  return PairingRepository(
    credentials: Credentials(store),
    zepp: ZeppClient(ZeppClient.dioFor()),
    scanner: FakeStrapScanner(),
  );
}

/// A client wired to [factory], with test-length timeouts.
StrapClient clientFor(StrapLinkFactory factory, {PairingRepository? pairing}) {
  return StrapClient(
    pairing: pairing ?? repositoryWith(mac: _mac, authKey: _authKey),
    linkFactory: factory,
    handshakeTimeout: const Duration(milliseconds: 400),
    dailyTotalsWait: const Duration(milliseconds: 300),
  );
}

/// A strap that answers the handshake and reports a plausible day.
FakeStrap healthyStrap({
  Map<int, List<Uint8List>>? rounds,
  bool hasActivityChannel = true,
}) => FakeStrap(
  authKey: parseAuthKey(_authKey),
  rounds: rounds,
  hasActivityChannel: hasActivityChannel,
  dailyTotals: (9264, 6710, 412),
);

/// One stress round, so a sync has something to decode.
Map<int, List<Uint8List>> stressRounds() => {
  0x13: [
    Uint8List.fromList([40, 41, 0xFF, 43]),
  ],
};

void main() {
  group('the credentials come from the keystore, never from a define', () {
    test('with no pairing, nothing touches the radio at all', () async {
      var built = 0;
      final client = clientFor(
        (mac) {
          built++;
          return healthyStrap();
        },
        pairing: repositoryWith(),
      );

      await expectLater(
        client.connect(),
        throwsA(
          isA<StrapException>().having(
            (e) => e.failure,
            'failure',
            isA<StrapNotPaired>(),
          ),
        ),
      );
      expect(built, 0, reason: 'no MAC means there is nothing to connect to');
    });

    test('half a pairing is no pairing', () async {
      final client = clientFor(
        (_) => healthyStrap(),
        pairing: repositoryWith(mac: _mac),
      );

      await expectLater(client.connect(), throwsA(isA<StrapException>()));
    });

    test('the stored MAC is the one the link is built for', () async {
      String? asked;
      final client = clientFor((mac) {
        asked = mac;
        return healthyStrap();
      });

      final session = await client.connect();
      expect(asked, _mac);
      await session.close();
    });
  });

  group('connect runs the real handshake', () {
    test('a correct key opens a session with a derived key on both sides', () async {
      late FakeStrap strap;
      final client = clientFor((_) => strap = healthyStrap());

      final session = await client.connect();
      expect(strap.proofAccepted, isTrue);
      expect(session.comms.sessionKey, equals(strap.deviceSessionKey));
      expect(session.batteryPercent, 71);
      expect(session.hasActivityChannel, isTrue);
      await session.close();
      expect(strap.closed, isTrue);
    });

    test('a key the strap rejects is reported as a wrong key, and closes', () async {
      late FakeStrap strap;
      final client = clientFor(
        (_) => strap = FakeStrap(
          authKey: parseAuthKey(_authKey),
          rejectAuthKey: true,
        ),
      );

      await expectLater(
        client.connect(),
        throwsA(
          isA<StrapException>().having(
            (e) => e.failure,
            'failure',
            isA<HandshakeRefused>().having(
              (f) => f.isWrongKey,
              'isWrongKey',
              isTrue,
            ),
          ),
        ),
      );
      expect(
        strap.closed,
        isTrue,
        reason: 'a half-open link holds the strap against the next attempt',
      );
    });

    test('a strap that goes quiet mid-handshake times out, distinctly', () async {
      final client = clientFor(
        (_) => FakeStrap(
          authKey: parseAuthKey(_authKey),
          silentDuringHandshake: true,
        ),
      );

      await expectLater(
        client.connect(),
        throwsA(
          isA<StrapException>().having(
            (e) => e.failure,
            'failure',
            isA<HandshakeTimedOut>(),
          ),
        ),
      );
    });

    test('a strap that is not there is unreachable, not refused', () async {
      final client = clientFor(
        (_) => FakeStrap(authKey: parseAuthKey(_authKey), unreachable: true),
      );

      await expectLater(
        client.connect(),
        throwsA(
          isA<StrapException>().having(
            (e) => e.failure,
            'failure',
            isA<StrapUnreachable>(),
          ),
        ),
      );
    });
  });

  group('one sync, end to end', () {
    test('samples come back typed, sentinel-filtered, with the battery', () async {
      final client = clientFor((_) => healthyStrap(rounds: stressRounds()));

      final result = await client.syncOnce(const StrapSyncWindow.firstEver());

      expect(
        result.samples.map((s) => s.value).toList(),
        [40, 41, 43],
        reason: 'the 0xFF minute is a hole, not a stress reading',
      );
      expect(result.samples.every((s) => s.metric == 'stress'), isTrue);
      expect(result.batteryPercent, 71);
      expect(result.stressBackfillRan, isTrue);
      expect(result.napBackfillRan, isTrue);
    });

    test('THE DAILY TOTAL SURVIVES — the counter reaches the result', () async {
      // #121: this is the authoritative step count, and on the server it is the
      // one measurement a re-derive could destroy because nothing durable held
      // it. Losing it on the phone would recreate that, one layer up.
      final client = clientFor((_) => healthyStrap(rounds: stressRounds()));

      final result = await client.syncOnce(const StrapSyncWindow.firstEver());

      expect(result.dailyTotals, isNotNull);
      expect(result.dailyTotals!.steps, 9264);
      expect(result.dailyTotals!.distanceM, 6710);
      expect(result.dailyTotals!.calories, 412);
      // The reply came back ENCRYPTED under the session key, so this value
      // arriving intact also proves both sides derived the same key.
      expect(result.asStrapData().dailyTotals!.steps, 9264);
    });

    test('a strap with no activity channel still reports its counter', () async {
      // Legacy returned before even asking in this case. The counter has no
      // other home, so it is now requested first.
      final client = clientFor((_) => healthyStrap(hasActivityChannel: false));

      final result = await client.syncOnce(const StrapSyncWindow.firstEver());
      expect(result.dailyTotals!.steps, 9264);
      expect(result.samples, isEmpty);
    });

    test('a strap that never answers with totals reports null, not zero', () async {
      final client = clientFor((_) => FakeStrap(authKey: parseAuthKey(_authKey)));

      final result = await client.syncOnce(const StrapSyncWindow.firstEver());
      expect(
        result.dailyTotals,
        isNull,
        reason: '"the strap did not say" is not "the owner took no steps"',
      );
    });

    test('every metric in the fetch plan is actually asked for', () async {
      late FakeStrap strap;
      final client = clientFor((_) => strap = healthyStrap());

      await client.syncOnce(const StrapSyncWindow.firstEver());

      final asked = strap.requestedCodes.toSet();
      for (final (code, name, _) in kFetchPlan) {
        expect(asked, contains(code), reason: 'the plan lists $name');
      }
      expect(asked, contains(0x48), reason: 'sleep');
      expect(asked, contains(0x05), reason: 'workouts');
    });

    test('a watermark moves the fetch window forward', () async {
      late FakeStrap strap;
      final client = clientFor((_) => strap = healthyStrap());

      final watermark = DateTime.now().subtract(const Duration(hours: 6));
      await client.syncOnce(
        StrapSyncWindow(
          lastSampleAt: {'stress': watermark},
          napBackfillDone: true,
          stressBackfillDone: true,
        ),
      );

      // The stress start command must be one minute past the watermark, not
      // thirty days back.
      final asked = strap.firstRequestFor(0x13)!;
      expect(
        asked.difference(
          DateTime(
            watermark.year,
            watermark.month,
            watermark.day,
            watermark.hour,
            watermark.minute,
          ),
        ),
        const Duration(minutes: 1),
        reason: 'incremental means resume, not re-download',
      );
    });

    test('with no watermark a metric is fetched from the 30-day floor', () async {
      late FakeStrap strap;
      final client = clientFor((_) => strap = healthyStrap());

      await client.syncOnce(const StrapSyncWindow.firstEver());

      final asked = strap.firstRequestFor(0x13)!;
      expect(
        DateTime.now().difference(asked).inDays,
        kBackfillWindow.inDays,
      );
    });

    test('the one-shot flags are reported as RAN, not as "should be true"', () async {
      final client = clientFor((_) => healthyStrap());

      final result = await client.syncOnce(
        const StrapSyncWindow(napBackfillDone: true, stressBackfillDone: true),
      );

      expect(result.stressBackfillRan, isFalse);
      expect(result.napBackfillRan, isFalse);
    });

    test('the session is closed when the sync finishes', () async {
      late FakeStrap strap;
      final client = clientFor((_) => strap = healthyStrap());

      await client.syncOnce(const StrapSyncWindow.firstEver());
      expect(strap.closed, isTrue);
    });
  });
}
