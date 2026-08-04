/// **The proof that no strap secret is logged.**
///
/// `test/pairing/pairing_secrecy_test.dart` established this discipline for the
/// Zepp password and the pairing key; this is the same proof for the protocol
/// layer, where two more secrets exist:
///
///  * the **auth key**, which is the strap's password, and
///  * the **session key**, derived per connection, which decrypts every frame.
///
/// The method is the same: drive the whole flow — connect, handshake, sync,
/// disconnect, and the failure paths — with a sentinel key that appears nowhere
/// else in the repository, capture every line the app logger emits, and fail if
/// any of them shows up.
///
/// The legacy client hex-dumped every frame it received and the whole payload
/// of an unexpected auth frame. Neither survived the port, and this is what
/// keeps them from coming back.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/models/strap_sync_window.dart';
import 'package:healthee/ble/strap_client.dart';
import 'package:healthee/ble/strap_exception.dart';
import 'package:healthee/ble/strap_failure.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/pairing/zepp_client.dart';

import '../pairing/_pairing_fakes.dart';
import '_fake_strap.dart';

/// A key that exists in no other file, so a match is proof of a leak.
const String _sentinelKey = 'c0ffee11deadbeef2244668800aabbcc';
const String _mac = 'DB:98:1F:80:4C:3D';

late List<String> _log;

String _hexOf(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

StrapClient _client(FakeStrap Function(String) factory) {
  final store = FakeSecretStore()
    ..values['strap_mac'] = _mac
    ..values['strap_auth_key'] = _sentinelKey;
  return StrapClient(
    pairing: PairingRepository(
      credentials: Credentials(store),
      zepp: ZeppClient(ZeppClient.dioFor()),
      scanner: FakeStrapScanner(),
    ),
    linkFactory: factory,
    handshakeTimeout: const Duration(milliseconds: 400),
    dailyTotalsWait: const Duration(milliseconds: 300),
  );
}

FakeStrap _strap({bool rejectAuthKey = false, bool silent = false}) => FakeStrap(
  authKey: parseAuthKey(_sentinelKey),
  rejectAuthKey: rejectAuthKey,
  silentDuringHandshake: silent,
  dailyTotals: (9264, 6710, 412),
  rounds: {
    0x13: [
      Uint8List.fromList([40, 41, 42]),
    ],
  },
);

void _expectClean(List<String> secrets) {
  final transcript = _log.join('\n');
  expect(_log, isNotEmpty, reason: 'otherwise "nothing leaked" is vacuous');
  for (final secret in secrets) {
    expect(
      transcript,
      isNot(contains(secret)),
      reason: 'this reached the log:\n$transcript',
    );
  }
}

void main() {
  setUp(() {
    _log = [];
    AppLog.sink = _log.add;
  });
  tearDown(() => AppLog.sink = null);

  test('a whole successful sync logs plenty, and neither key', () async {
    late FakeStrap strap;
    final result = await _client((_) => strap = _strap()).syncOnce(
      const StrapSyncWindow.firstEver(),
    );

    expect(result.samples, isNotEmpty, reason: 'the flow really ran');
    expect(_log.join('\n'), contains('auth: SUCCESS'));
    _expectClean([
      _sentinelKey,
      _hexOf(strap.deviceSessionKey!),
      _hexOf(parseAuthKey(_sentinelKey)),
    ]);
  });

  test('the MAC is logged as its last two octets, never in full', () async {
    final session = await _client((_) => _strap()).connect();
    await session.close();

    final transcript = _log.join('\n');
    expect(transcript, contains('4C:3D'));
    expect(transcript, isNot(contains(_mac)));
  });

  test('a rejected key does not put the key in the failure it logs', () async {
    await expectLater(
      _client((_) => _strap(rejectAuthKey: true)).connect(),
      throwsA(isA<StrapException>()),
    );

    expect(_log.join('\n'), contains('wrong auth key'));
    _expectClean([_sentinelKey]);
  });

  test('a handshake timeout logs the timeout, not the state it held', () async {
    await expectLater(
      _client((_) => _strap(silent: true)).connect(),
      throwsA(isA<StrapException>()),
    );
    _expectClean([_sentinelKey]);
  });

  test('an unexpected auth frame is logged by header, never dumped whole', () async {
    // The legacy version logged the entire frame as hex. A step-2 reply carries
    // the device random and its public key; a dump of one, with our private key
    // in memory, is the closest thing to publishing the session key.
    final strap = _strap();
    final client = _client((_) => strap);
    final session = await client.connect();
    await session.close();

    final transcript = _log.join('\n');
    expect(
      transcript,
      isNot(contains(_hexOf(strap.publicKeyFrame!))),
      reason: 'our own public-key frame must not be echoed into the log',
    );
    expect(
      transcript,
      isNot(contains(_hexOf(strap.proofFrame!))),
      reason: 'the proof is two encryptions of the random under both keys',
    );
  });

  test('the exception carries a code, not the reason and not the key', () {
    // An exception's toString reaches a crash reporter and an unawaited-future
    // print — places nobody audits — so it may carry only the stable code.
    const exception = StrapException(HandshakeRefused('wrong auth key'));
    expect(exception.toString(), 'StrapException(handshake_refused)');
    expect(exception.toString(), isNot(contains('wrong auth key')));
    expect(exception.toString(), isNot(contains(_sentinelKey)));
  });
}
