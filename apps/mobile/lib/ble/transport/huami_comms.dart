/// Post-auth chunked comms over chars `0x0016` (write) / `0x0017` (notify).
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// huami_comms.dart`. Handles fragmentation, optional AES encryption under the
/// session key, and the chunked ACK the device requires whenever flag `0x04` is
/// set on a frame.
///
/// ## Offset table — the ACK we write back to char 0x0017
///
/// | offset | size | value |
/// |---|---|---|
/// | 0 | 1 | `0x04` — ACK marker |
/// | 1 | 1 | `0x00` |
/// | 2 | 1 | the frame's `handle` |
/// | 3 | 1 | `0x01` |
/// | 4 | 1 | the frame's `count` |
///
/// ## One adaptation
///
/// The legacy `log` callback is replaced by [AppLog]. A failed ACK write is
/// still logged-and-continued rather than thrown — the ACK is the device's
/// flow-control courtesy, and losing one does not invalidate the frame we just
/// decoded — but it now reaches the platform log in release builds with the
/// error object and its stack, which `debugPrint` did not.
library;

import 'dart:typed_data';

import 'package:healthee/ble/transport/huami_chunk.dart';
import 'package:healthee/core/logging.dart';

/// The framed, optionally-encrypted message channel to the strap.
class HuamiComms {
  /// [writeChunk] goes to char `0x0016`, [writeAck] to char `0x0017`.
  /// [sessionKey] and [sequence] come from a completed [ZeppOsAuth].
  HuamiComms({
    required this.writeChunk,
    required this.writeAck,
    required this.onPayload,
    this.sessionKey,
    int sequence = 0,
    int mtu = 247,
  }) : _encoder = HuamiChunkedEncoder(mtu: mtu) {
    if (sessionKey != null) _encoder.setEncryption(sessionKey!, sequence);
  }

  final HuamiChunkedEncoder _encoder;
  final HuamiChunkedDecoder _decoder = HuamiChunkedDecoder();

  /// The 16-byte session key. **A secret** — never logged.
  Uint8List? sessionKey;

  /// Writes one chunk to char `0x0016`.
  final Future<void> Function(Uint8List) writeChunk;

  /// Writes one ACK to char `0x0017`.
  final Future<void> Function(Uint8List) writeAck;

  /// Called with every reassembled frame.
  final void Function(int endpoint, Uint8List payload) onPayload;

  /// Sends one logical message on [endpoint].
  Future<void> send(int endpoint, Uint8List data, {bool encrypt = false}) async {
    for (final chunk in _encoder.encode(endpoint, data, encrypt: encrypt)) {
      await writeChunk(chunk);
    }
  }

  /// Feed every notification value from char `0x0017` here.
  Future<void> onNotify(Uint8List value) async {
    final f = _decoder.feed(value, sessionKey: sessionKey);
    if (f == null) return;
    if (f.needsAck) {
      try {
        await writeAck(Uint8List.fromList([0x04, 0x00, f.handle, 0x01, f.count]));
      } on Exception catch (error, stackTrace) {
        AppLog.failure(
          'ble',
          'acknowledging a chunked frame from the strap',
          error,
          stackTrace,
        );
      }
    }
    onPayload(f.endpoint, f.payload);
  }
}
