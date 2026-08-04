/// **Spec-derived.** The peer in these tests is [FakeStrap], whose device half
/// is written from `research/protocol/zeppos_ble_handshake.md` § "The auth
/// handshake" — the five steps, their byte offsets, the two status codes, and
/// the derivation
///
/// > `encryptedSequenceNumber = uint32_LE(sharedEC[0..4])`
/// > `sessionAES[i] = sharedEC[i + 8] ^ secretKey[i]`
///
/// written out there rather than read from `zeppos_auth.dart`. So an offset or
/// a XOR that drifted in `lib/` fails here.
///
/// What is NOT proven: that the doc matches the strap. Both halves of this test
/// believe the same document. Only the owner's hardware can settle that, and it
/// fails closed if the document is wrong — status `0x25`, not a wrong number.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/transport/huami_chunk.dart';
import 'package:healthee/ble/transport/zeppos_auth.dart';

import '_fake_strap.dart';

const String _authKeyHex = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// Wires [ZeppOsAuth] to a [FakeStrap] and runs the handshake to a conclusion.
Future<({ZeppOsAuth auth, FakeStrap strap, String? failure})> handshake({
  bool rejectAuthKey = false,
  Uint8List? appKey,
}) async {
  final deviceKey = parseAuthKey(_authKeyHex);
  final strap = FakeStrap(authKey: deviceKey, rejectAuthKey: rejectAuthKey);
  final done = Completer<String?>();
  final auth = ZeppOsAuth(
    authKey: appKey ?? deviceKey,
    writeChunk: strap.writeChunk,
    onSuccess: () {
      if (!done.isCompleted) done.complete(null);
    },
    onFailure: (reason) {
      if (!done.isCompleted) done.complete(reason);
    },
  );
  final subscription = strap.chunkedNotifications.listen(auth.onNotify);
  await auth.start();
  final failure = await done.future.timeout(
    const Duration(seconds: 5),
    onTimeout: () => 'test timed out',
  );
  await subscription.cancel();
  await strap.close();
  return (auth: auth, strap: strap, failure: failure);
}

void main() {
  group('the happy path', () {
    test('step 1 is [04 02 00 02] then the 48-byte public key', () async {
      final result = await handshake();
      final frame = result.strap.publicKeyFrame!;

      expect(frame.length, 52);
      expect(Uint8List.sublistView(frame, 0, 4), equals([0x04, 0x02, 0x00, 0x02]));
      expect(Uint8List.sublistView(frame, 4).length, 48);
    });

    test('step 4 is [05] then both encryptions of the device random', () async {
      final result = await handshake();
      final proof = result.strap.proofFrame!;

      expect(proof.length, 33);
      expect(proof[0], 0x05);
      expect(
        result.strap.proofAccepted,
        isTrue,
        reason: 'the device checked both halves against its own random',
      );
    });

    test('both sides derive the SAME session key and sequence', () async {
      final result = await handshake();

      expect(result.failure, isNull);
      expect(result.auth.state, AuthState.success);
      expect(result.auth.sessionKey, equals(result.strap.deviceSessionKey));
      expect(result.auth.sequence, result.strap.deviceSequence);
      expect(result.auth.sessionKey, hasLength(16));
    });

    test('the session key is not the auth key', () async {
      final result = await handshake();
      expect(result.auth.sessionKey, isNot(equals(parseAuthKey(_authKeyHex))));
    });
  });

  group('the refusals stay distinguishable', () {
    test('status 0x25 is reported as a wrong auth key, by name', () async {
      final result = await handshake(rejectAuthKey: true);

      expect(result.failure, 'wrong auth key');
      expect(result.auth.state, AuthState.failed);
    });

    test('a key the device does not hold fails the proof, not the framing', () async {
      final result = await handshake(
        appKey: parseAuthKey('00112233445566778899aabbccddeeff'),
      );

      expect(result.strap.proofFrame, isNotNull, reason: 'we still got to step 4');
      expect(result.strap.proofAccepted, isFalse);
      expect(result.failure, 'wrong auth key');
    });

    test('a 15-byte key is refused at construction, before any radio use', () {
      expect(
        () => ZeppOsAuth(authKey: Uint8List(15), writeChunk: (_) async {}),
        throwsArgumentError,
      );
    });
  });

  group('malformed replies do not become a session', () {
    /// Starts a handshake, hands it [payload] as a device reply on endpoint
    /// 0x0082, and returns the failure reason (or `'SUCCEEDED'`, which is
    /// always wrong here).
    Future<({String? reason, ZeppOsAuth auth})> replyWith(
      Uint8List payload,
    ) async {
      String? reason;
      final auth = ZeppOsAuth(
        authKey: parseAuthKey(_authKeyHex),
        writeChunk: (_) async {},
        onSuccess: () => reason = 'SUCCEEDED',
        onFailure: (why) => reason ??= why,
      );
      await auth.start();
      for (final chunk in HuamiChunkedEncoder().encode(
        ZeppOsAuth.endpoint,
        payload,
      )) {
        auth.onNotify(chunk);
      }
      return (reason: reason, auth: auth);
    }

    test('a truncated pub-key reply is refused, not padded out', () async {
      final short = Uint8List(20)
        ..[0] = 0x10
        ..[1] = 0x04
        ..[2] = 0x01;
      final result = await replyWith(short);
      expect(result.reason, contains('too short'));
      expect(result.auth.sessionKey, isNull);
    });

    test('a non-success status on step 2 ends it', () async {
      final refused = Uint8List(67)
        ..[0] = 0x10
        ..[1] = 0x04
        ..[2] = 0x02;
      final result = await replyWith(refused);
      expect(result.reason, contains('status=0x2'));
      expect(result.auth.sessionKey, isNull);
    });

    test('a frame that is not a RESPONSE is ignored, not acted on', () async {
      final result = await replyWith(Uint8List.fromList([0x99, 0x04, 0x01]));
      expect(result.reason, isNull);
      expect(result.auth.state, AuthState.sentPubKey, reason: 'still waiting');
      expect(result.auth.sessionKey, isNull);
    });
  });
}
