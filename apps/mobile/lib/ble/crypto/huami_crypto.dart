/// The two crypto primitives the Huami/ZeppOS wire format needs, plus the
/// auth-key decoder.
///
/// **Ported verbatim** from `~/projects/healthee-legacy/app/lib/ble/
/// huami_crypto.dart`. AES-128/ECB/NoPadding matches Gadgetbridge's
/// `CryptoUtils.encryptAES` and HelioCore's `AES128.ecbEncrypt`; the CRC-32 is
/// the IEEE/zlib one Gadgetbridge's `CheckSums.getCRC32` computes.
///
/// This is a different key and a different cipher from `data/pairing/
/// zepp_crypto.dart`, which does AES-CBC/PKCS7 over the Zepp *cloud* login body.
/// The two are unrelated and deliberately not merged: one talks to a website,
/// one talks to a radio.
library;

import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-128/ECB/NoPadding encrypt.
///
/// Used by the ZeppOS auth proof-of-knowledge step (encrypt the device's
/// 16-byte random under both the auth key and the derived session key) and by
/// the post-auth chunked channel.
Uint8List aesEcbEncrypt(Uint8List key, Uint8List data) {
  if (key.length != 16) {
    throw ArgumentError('AES-128 needs a 16-byte key, got ${key.length}');
  }
  if (data.isEmpty || data.length % 16 != 0) {
    throw ArgumentError('ECB input must be a non-zero multiple of 16 bytes');
  }
  final cipher = ECBBlockCipher(AESEngine())..init(true, KeyParameter(key));
  final out = Uint8List(data.length);
  for (var off = 0; off < data.length; off += 16) {
    cipher.processBlock(data, off, out, off);
  }
  return out;
}

/// AES-128/ECB/NoPadding decrypt — for the post-auth chunked data channel.
Uint8List aesEcbDecrypt(Uint8List key, Uint8List data) {
  if (key.length != 16) {
    throw ArgumentError('AES-128 needs a 16-byte key, got ${key.length}');
  }
  if (data.isEmpty || data.length % 16 != 0) {
    throw ArgumentError('ECB input must be a non-zero multiple of 16 bytes');
  }
  final cipher = ECBBlockCipher(AESEngine())..init(false, KeyParameter(key));
  final out = Uint8List(data.length);
  for (var off = 0; off < data.length; off += 16) {
    cipher.processBlock(data, off, out, off);
  }
  return out;
}

// CRC-32 (IEEE, zlib/ISO-HDLC) — used in the encrypted chunked frame trailer
// (Huami appends seq(4 LE) + crc32(4 LE) before AES). Matches GB
// CheckSums.getCRC32.
final List<int> _crc32Table = _buildCrc32Table();

List<int> _buildCrc32Table() {
  final t = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    t[n] = c;
  }
  return t;
}

/// CRC-32 (IEEE) over `data[start..end)`.
int crc32(Uint8List data, [int start = 0, int? end]) {
  final last = end ?? data.length;
  var crc = 0xFFFFFFFF;
  for (var i = start; i < last; i++) {
    crc = _crc32Table[(crc ^ data[i]) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Parses a Huami auth key string (`0x<32 hex>` or `<32 hex>`) to 16 bytes.
///
/// This is the one bridge from `PairedStrap.authKey`, which is stored as the
/// normalised 32-character string, to the bytes the handshake XORs.
Uint8List parseAuthKey(String s) {
  var h = s.trim();
  if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
  if (h.length != 32) {
    throw ArgumentError('auth key must be 32 hex chars (16 bytes)');
  }
  final out = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
