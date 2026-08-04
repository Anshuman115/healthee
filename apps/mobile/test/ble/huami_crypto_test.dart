/// **Spec-derived.** Every vector here is published, and none of it was read
/// off our own implementation.
///
///  * AES-128/ECB — FIPS-197, Appendix C.1 ("AES-128 (Nk=4, Nr=10)").
///  * CRC-32/ISO-HDLC — the standard check value for the ASCII string
///    `"123456789"`, which is how every catalogued CRC is identified.
///
/// These matter because both primitives sit under the handshake: a wrong AES
/// makes the proof-of-knowledge fail as "wrong auth key", and a wrong CRC makes
/// the strap silently discard every encrypted frame we send.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/huami_crypto.dart';

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _hexOf(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('AES-128/ECB against the FIPS-197 known-answer vector', () {
    // FIPS-197 C.1: key 000102…0f, plaintext 0011…ff, ciphertext 69c4…5a.
    final key = _hex('000102030405060708090a0b0c0d0e0f');
    final plaintext = _hex('00112233445566778899aabbccddeeff');
    const ciphertext = '69c4e0d86a7b0430d8cdb78070b4c55a';

    test('encrypt produces the published ciphertext', () {
      expect(_hexOf(aesEcbEncrypt(key, plaintext)), ciphertext);
    });

    test('decrypt inverts it', () {
      expect(_hexOf(aesEcbDecrypt(key, _hex(ciphertext))), _hexOf(plaintext));
    });

    test('ECB has no chaining: two identical blocks encrypt identically', () {
      final doubled = Uint8List(32)
        ..setRange(0, 16, plaintext)
        ..setRange(16, 32, plaintext);
      final out = aesEcbEncrypt(key, doubled);
      expect(_hexOf(Uint8List.sublistView(out, 0, 16)), ciphertext);
      expect(_hexOf(Uint8List.sublistView(out, 16, 32)), ciphertext);
    });

    test('a wrong key length is refused, not silently coerced', () {
      expect(
        () => aesEcbEncrypt(Uint8List(15), plaintext),
        throwsArgumentError,
      );
      expect(() => aesEcbEncrypt(key, Uint8List(17)), throwsArgumentError);
      expect(() => aesEcbEncrypt(key, Uint8List(0)), throwsArgumentError);
    });
  });

  group('CRC-32 against the catalogued check value', () {
    test('"123456789" is 0xCBF43926', () {
      final data = Uint8List.fromList('123456789'.codeUnits);
      expect(crc32(data), 0xCBF43926);
    });

    test('the empty range is 0', () {
      expect(crc32(Uint8List(0)), 0);
    });

    test('the range arguments select a sub-slice, not the whole buffer', () {
      final padded = Uint8List.fromList([0xAA, ...'123456789'.codeUnits, 0xBB]);
      expect(crc32(padded, 1, 10), 0xCBF43926);
    });
  });

  group('the auth key is decoded, not guessed at', () {
    test('with and without the 0x prefix, either case', () {
      const key = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
      expect(_hexOf(parseAuthKey(key)), key);
      expect(_hexOf(parseAuthKey('0x$key')), key);
      expect(_hexOf(parseAuthKey('0X${key.toUpperCase()}')), key);
      expect(_hexOf(parseAuthKey('  $key  ')), key);
    });

    test('31 hex digits is a different key, not a typo we fix', () {
      expect(() => parseAuthKey('a' * 31), throwsArgumentError);
      expect(() => parseAuthKey('a' * 33), throwsArgumentError);
      expect(() => parseAuthKey(''), throwsArgumentError);
    });
  });
}
