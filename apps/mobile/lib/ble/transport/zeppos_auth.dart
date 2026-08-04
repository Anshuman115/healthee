/// The ZeppOS / Huami-2021 auth handshake, over logical endpoint `0x0082`.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// zeppos_auth.dart`. The five steps are written down independently in
/// `research/protocol/zeppos_ble_handshake.md` § "The auth handshake", and
/// `test/ble/zeppos_auth_test.dart` builds its fake device from that document
/// rather than from this code.
///
/// Transport-agnostic: the caller supplies [writeChunk] (writes one BLE chunk
/// to char `0x0016`) and feeds notifications from char `0x0017` into [onNotify].
/// On success, [sessionKey] (16 bytes) and [sequence] (uint32) are set — those
/// two drive AES encryption of every post-auth frame.
///
/// ## Offset table — the frames on endpoint 0x0082
///
/// **Step 1, app → device** (52 bytes):
///
/// | offset | size | value |
/// |---|---|---|
/// | 0 | 4 | `04 02 00 02` — CMD_PUB_KEY |
/// | 4 | 48 | our ECDH public key, `x[24] ‖ y[24]` |
///
/// **Step 2, device → app** (67 bytes):
///
/// | offset | size | field |
/// |---|---|---|
/// | 0 | 1 | `0x10` — RESPONSE |
/// | 1 | 1 | `0x04` — echo of CMD_PUB_KEY |
/// | 2 | 1 | status: `0x01` success |
/// | 3 | 16 | `remoteRandom` |
/// | 19 | 48 | `remotePublicEC` |
///
/// **Step 3, derivation** (no bytes on the wire):
/// `sharedEC = ECDH(priv, remotePublicEC)`;
/// `sequence = uint32LE(sharedEC[0..4])`;
/// `sessionKey[i] = sharedEC[i + 8] ^ authKey[i]` for i in 0..16.
///
/// **Step 4, app → device** (33 bytes):
///
/// | offset | size | value |
/// |---|---|---|
/// | 0 | 1 | `0x05` — CMD_SESSION_KEY |
/// | 1 | 16 | `AES_ECB(remoteRandom, authKey)` |
/// | 17 | 16 | `AES_ECB(remoteRandom, sessionKey)` |
///
/// **Step 5, device → app**: `[0x10, 0x05, status]`, where status `0x01` is
/// success and `0x25` means the auth key is wrong.
///
/// ## Two adaptations, both forced by the standards
///
///  * The legacy `log` callback is gone; every line goes through [AppLog].
///    **No secret is logged** — not the auth key, not the derived session key,
///    and not the payload of an unexpected frame (only its length and its
///    three-byte header, which is the part with diagnostic value). The legacy
///    version hex-dumped whole frames.
///  * `_sendProof` is awaited inside its own error handler rather than
///    fire-and-forget. A write that fails now ends the handshake with a named
///    reason instead of leaving an unhandled async error and a timeout.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:healthee/ble/crypto/ecdh_sect163k1.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/transport/huami_chunk.dart';
import 'package:healthee/core/logging.dart';

/// Where the handshake has got to.
enum AuthState {
  /// Nothing sent yet.
  idle,

  /// Step 1 written; waiting for the device's random + public key.
  sentPubKey,

  /// Step 4 written; waiting for the confirmation.
  sentSessionKey,

  /// Authenticated. [ZeppOsAuth.sessionKey] and `sequence` are set.
  success,

  /// Refused or unusable — see the reason passed to `onFailure`.
  failed,
}

/// Runs the five-step ZeppOS handshake and derives the session key.
class ZeppOsAuth {
  /// [authKey] must be the strap's 16-byte pairing key.
  ZeppOsAuth({
    required this.authKey,
    required this.writeChunk,
    this.onSuccess,
    this.onFailure,
  }) {
    if (authKey.length != 16) {
      throw ArgumentError('authKey must be 16 bytes');
    }
  }

  /// The logical endpoint the handshake is multiplexed onto.
  static const int endpoint = 0x0082;

  /// The strap's 16-byte pairing key. **A secret** — never logged, never sent
  /// anywhere but into the cipher below.
  final Uint8List authKey;

  /// Writes one chunk to char `0x0016`.
  final Future<void> Function(Uint8List chunk) writeChunk;

  /// Called once, when the device confirms.
  void Function()? onSuccess;

  /// Called once, with a short secret-free reason.
  void Function(String reason)? onFailure;

  final HuamiChunkedEncoder _encoder = HuamiChunkedEncoder();
  final HuamiChunkedDecoder _decoder = HuamiChunkedDecoder();

  Uint8List? _priv;
  Uint8List? _pub;

  /// The derived 16-byte session key, or null before step 3. **A secret.**
  Uint8List? sessionKey;

  /// The initial encryption sequence number, or null before step 3.
  int? sequence;

  /// Where the handshake has got to.
  AuthState state = AuthState.idle;

  /// Step 1 — generate a keypair and send the public half.
  Future<void> start() async {
    final kp = EcdhSect163k1.generateKeypair();
    _priv = kp.$1;
    _pub = kp.$2;
    final payload = Uint8List(52)
      ..setRange(0, 4, const [0x04, 0x02, 0x00, 0x02])
      ..setRange(4, 52, _pub!);
    state = AuthState.sentPubKey;
    AppLog.info('ble', 'auth: sending public key');
    await _send(payload);
  }

  Future<void> _send(Uint8List payload) async {
    for (final chunk in _encoder.encode(endpoint, payload)) {
      await writeChunk(chunk);
    }
  }

  /// Feed every notification value from char `0x0017` here.
  void onNotify(Uint8List value) {
    final frame = _decoder.feed(value);
    if (frame == null || frame.endpoint != endpoint) return;
    final p = frame.payload;
    if (p.length < 3 || p[0] != 0x10) {
      AppLog.warning('ble', 'auth: unexpected frame ${_header(p)}');
      return;
    }
    final cmd = p[1];
    final status = p[2];
    if (cmd == 0x04) {
      _handlePubKeyReply(status, p);
    } else if (cmd == 0x05) {
      _handleSessionReply(status, p);
    }
  }

  void _handlePubKeyReply(int status, Uint8List p) {
    if (status != 0x01) {
      _fail('pub-key reply status=0x${status.toRadixString(16)}');
      return;
    }
    if (p.length < 67) {
      _fail('pub-key reply too short (${p.length})');
      return;
    }
    final random = Uint8List.fromList(p.sublist(3, 19));
    final remotePub = Uint8List.fromList(p.sublist(19, 67));
    final shared = EcdhSect163k1.generateShared(_priv!, remotePub);
    sequence = ByteData.sublistView(shared, 0, 4).getUint32(0, Endian.little);
    final session = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      session[i] = shared[i + 8] ^ authKey[i];
    }
    sessionKey = session;
    final enc1 = aesEcbEncrypt(authKey, random);
    final enc2 = aesEcbEncrypt(session, random);
    final cmd = Uint8List(33)
      ..[0] = 0x05
      ..setRange(1, 17, enc1)
      ..setRange(17, 33, enc2);
    state = AuthState.sentSessionKey;
    AppLog.info('ble', 'auth: derived session key, sending proof');
    unawaited(_sendProof(cmd));
  }

  Future<void> _sendProof(Uint8List command) async {
    try {
      await _send(command);
    } on Exception catch (error, stackTrace) {
      AppLog.failure('ble', 'writing the auth proof to the strap', error, stackTrace);
      _fail('the proof could not be written');
    }
  }

  void _handleSessionReply(int status, Uint8List p) {
    if (status == 0x25) {
      _fail('wrong auth key');
      return;
    }
    if (status != 0x01) {
      _fail('session reply status=0x${status.toRadixString(16)}');
      return;
    }
    state = AuthState.success;
    AppLog.info('ble', 'auth: SUCCESS');
    onSuccess?.call();
  }

  void _fail(String reason) {
    state = AuthState.failed;
    AppLog.warning('ble', 'auth: FAILED — $reason');
    onFailure?.call(reason);
  }

  /// The three-byte RESPONSE/cmd/status header and the length — the part of an
  /// unexpected frame worth reading, and the part that cannot carry a key.
  static String _header(Uint8List b) {
    final head = b
        .take(3)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return '${b.length}B starting $head';
  }
}
