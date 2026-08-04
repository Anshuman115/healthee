/// **Spec-derived.** Every byte position asserted here is written down in
/// `research/protocol/zeppos_ble_handshake.md` § "Chunked transport framing":
///
/// > Per chunk written to char 0016 (MTU ~247): `[0x03, flags, 0x00,
/// > writeHandle, count]` then, **on the first chunk only**:
/// > `uint32LE(totalPayloadLen) + uint16LE(endpoint)`, then the payload slice.
/// > flags: `0x01`=first, `0x02`=last, `0x04`=set with last, `0x08`=encrypted.
/// > `writeHandle` increments per message; `count` increments per chunk.
/// > … if `encrypted` flag set, length is padded to a 16-byte boundary after +8.
///
/// The encrypted-frame trailer (`seq(4 LE) ‖ crc32(4 LE)`, and the per-message
/// key `sessionKey[i] ^ writeHandle`) comes from the file's own header comment,
/// which cites Gadgetbridge as its source. The four round-trip tests are the
/// legacy suite carried across.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';
import 'package:healthee/ble/transport/huami_chunk.dart';

Uint8List _seq(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => i & 0xFF));

Uint8List _key() =>
    Uint8List.fromList(List<int>.generate(16, (i) => (i * 9 + 1) & 0xFF));

HuamiFrame? _feedAll(
  HuamiChunkedDecoder decoder,
  List<Uint8List> chunks, {
  Uint8List? sessionKey,
}) {
  HuamiFrame? frame;
  for (final chunk in chunks) {
    final f = decoder.feed(chunk, sessionKey: sessionKey);
    if (f != null) frame = f;
  }
  return frame;
}

void main() {
  group('the chunk header is exactly what the doc says', () {
    test('first chunk: 03 | flags | 00 | handle | count | len32 | endpoint16', () {
      final encoder = HuamiChunkedEncoder();
      final payload = Uint8List(52)
        ..setRange(0, 4, const [0x04, 0x02, 0x00, 0x02]);
      final chunk = encoder.encode(0x0082, payload).single;

      expect(chunk[0], 0x03, reason: 'chunked-transfer marker');
      expect(chunk[1], 0x07, reason: 'first(01) | last(02) | needsAck(04)');
      expect(chunk[2], 0x00, reason: 'reserved');
      expect(chunk[3], 0x01, reason: 'the first message gets handle 1');
      expect(chunk[4], 0x00, reason: 'chunk count starts at 0');
      expect(
        ByteData.sublistView(chunk, 5, 9).getUint32(0, Endian.little),
        52,
        reason: 'total payload length, uint32 LE',
      );
      expect(
        ByteData.sublistView(chunk, 9, 11).getUint16(0, Endian.little),
        0x0082,
        reason: 'endpoint, uint16 LE',
      );
      expect(Uint8List.sublistView(chunk, 11), equals(payload));
    });

    test('writeHandle increments per MESSAGE, count per CHUNK', () {
      final encoder = HuamiChunkedEncoder(mtu: 40);
      final first = encoder.encode(0x000a, _seq(100));
      final second = encoder.encode(0x000a, _seq(10));

      expect(first.length, greaterThan(1));
      expect(first.map((c) => c[3]).toSet(), {1}, reason: 'one handle each');
      expect(
        first.map((c) => c[4]).toList(),
        List<int>.generate(first.length, (i) => i),
        reason: 'count increments per chunk',
      );
      expect(second.single[3], 2, reason: 'the next message gets handle 2');
      expect(second.single[4], 0);
    });

    test('only the first chunk carries the length/endpoint header', () {
      final encoder = HuamiChunkedEncoder(mtu: 40);
      final chunks = encoder.encode(0x004b, _seq(200));

      expect(chunks.first[1] & 0x01, 0x01, reason: 'first flag on chunk 0');
      for (final chunk in chunks.skip(1)) {
        expect(chunk[1] & 0x01, 0, reason: 'and on no other');
      }
      expect(chunks.last[1] & 0x02, 0x02, reason: 'last flag on the last');
      expect(chunks.last[1] & 0x04, 0x04, reason: 'needs-ack rides with last');
      for (final chunk in chunks.take(chunks.length - 1)) {
        expect(chunk[1] & 0x02, 0);
      }
    });

    test('the MTU governs the split: (mtu-3) minus 11, then minus 5', () {
      final encoder = HuamiChunkedEncoder(mtu: 40);
      final chunks = encoder.encode(0x000a, _seq(100));
      expect(chunks.first.length, 11 + ((40 - 3) - 11));
      expect(chunks[1].length, 5 + ((40 - 3) - 5));
    });
  });

  group('encrypted frames pad, but the length field does not', () {
    test('ciphertext is pad16(len + 8); the header says the ORIGINAL length', () {
      final encoder = HuamiChunkedEncoder(mtu: 247)..setEncryption(_key(), 0);
      // 50 + 8 = 58 -> padded to 64.
      final chunk = encoder.encode(0x004b, _seq(50), encrypt: true).single;

      expect(chunk[1] & 0x08, 0x08, reason: 'encrypted flag');
      expect(
        ByteData.sublistView(chunk, 5, 9).getUint32(0, Endian.little),
        50,
        reason: 'the length field is the plaintext length',
      );
      expect(chunk.length - 11, 64, reason: 'the body is the padded ciphertext');
    });

    test('the plaintext trailer is seq(4 LE) then crc32(4 LE)', () {
      const sequence = 0x11223344;
      final key = _key();
      final encoder = HuamiChunkedEncoder(mtu: 247)
        ..setEncryption(key, sequence);
      final data = _seq(50);
      final chunk = encoder.encode(0x004b, data, encrypt: true).single;

      // Per-message key = sessionKey[i] ^ writeHandle, and this is message 1.
      final messageKey = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        messageKey[i] = key[i] ^ chunk[3];
      }
      final plain = aesEcbDecrypt(
        messageKey,
        Uint8List.sublistView(chunk, 11),
      );

      expect(Uint8List.sublistView(plain, 0, 50), equals(data));
      expect(
        ByteData.sublistView(plain, 50, 54).getUint32(0, Endian.little),
        sequence,
      );
      expect(
        ByteData.sublistView(plain, 54, 58).getUint32(0, Endian.little),
        crc32(plain, 0, 54),
      );
      for (var i = 58; i < plain.length; i++) {
        expect(plain[i], 0, reason: 'the pad is zeroes');
      }
    });

    test('the sequence number advances one per encrypted message', () {
      final key = _key();
      final encoder = HuamiChunkedEncoder(mtu: 247)..setEncryption(key, 7);
      final seqs = <int>[];
      for (var n = 0; n < 3; n++) {
        final chunk = encoder.encode(0x004b, _seq(16), encrypt: true).single;
        final messageKey = Uint8List(16);
        for (var i = 0; i < 16; i++) {
          messageKey[i] = key[i] ^ chunk[3];
        }
        final plain = aesEcbDecrypt(
          messageKey,
          Uint8List.sublistView(chunk, 11),
        );
        seqs.add(ByteData.sublistView(plain, 16, 20).getUint32(0, Endian.little));
      }
      expect(seqs, [7, 8, 9]);
    });

    test('asking to encrypt without a session key throws, never sends clear', () {
      final encoder = HuamiChunkedEncoder();
      expect(
        () => encoder.encode(0x004b, _seq(8), encrypt: true),
        throwsStateError,
      );
    });
  });

  group('round trips (the legacy suite, carried across)', () {
    test('single chunk', () {
      final data = _seq(40);
      final chunks = HuamiChunkedEncoder().encode(0x0082, data);
      expect(chunks.length, 1);
      final frame = _feedAll(HuamiChunkedDecoder(), chunks);
      expect(frame, isNotNull);
      expect(frame!.endpoint, 0x0082);
      expect(frame.encrypted, isFalse);
      expect(frame.needsAck, isTrue);
      expect(frame.payload, equals(data));
    });

    test('multi-chunk (payload > MTU)', () {
      final data = _seq(600);
      final chunks = HuamiChunkedEncoder().encode(0x000a, data);
      expect(chunks.length, greaterThan(1));
      final frame = _feedAll(HuamiChunkedDecoder(), chunks);
      expect(frame!.endpoint, 0x000a);
      expect(frame.payload, equals(data));
    });

    test('encrypted', () {
      final key = _key();
      final encoder = HuamiChunkedEncoder()..setEncryption(key, 0x11223344);
      final data = _seq(50);
      final frame = _feedAll(
        HuamiChunkedDecoder(),
        encoder.encode(0x004b, data, encrypt: true),
        sessionKey: key,
      );
      expect(frame!.endpoint, 0x004b);
      expect(frame.encrypted, isTrue);
      expect(frame.payload, equals(data));
    });

    test('an empty payload survives the round trip', () {
      final chunks = HuamiChunkedEncoder().encode(0x0082, Uint8List(0));
      final frame = _feedAll(HuamiChunkedDecoder(), chunks);
      expect(frame!.payload, isEmpty);
      expect(frame.endpoint, 0x0082);
    });
  });

  group('the decoder refuses what it cannot trust', () {
    test('a value that is not a chunk is ignored, not misread', () {
      final decoder = HuamiChunkedDecoder();
      expect(decoder.feed(Uint8List.fromList([0x99, 0, 0, 0, 0])), isNull);
      expect(decoder.feed(Uint8List.fromList([0x03, 0x07])), isNull);
    });

    test('an encrypted frame with no session key yields nothing, not garbage', () {
      final encoder = HuamiChunkedEncoder()..setEncryption(_key(), 1);
      final chunks = encoder.encode(0x004b, _seq(50), encrypt: true);
      expect(_feedAll(HuamiChunkedDecoder(), chunks), isNull);
    });

    test('a chunk from another message is dropped mid-reassembly', () {
      final decoder = HuamiChunkedDecoder();
      final encoder = HuamiChunkedEncoder(mtu: 40);
      final wanted = encoder.encode(0x000a, _seq(100));
      final other = encoder.encode(0x000a, _seq(100));

      expect(decoder.feed(wanted.first), isNull);
      // A stray continuation carrying a different handle must not be spliced in.
      expect(decoder.feed(other[1]), isNull);
      expect(_feedAll(decoder, wanted.skip(1).toList())!.payload, _seq(100));
    });
  });
}
