/// The two pure functions between a typed password and the bytes on the wire.
///
/// Both goldens were produced OUTSIDE this codebase, which is what makes them
/// evidence rather than a restatement:
///
///  * the form encoding is `urllib.parse.urlencode(payload, doseq=True)` — the
///    exact call the proven `huami_token` reference makes;
///  * the ciphertext is `openssl enc -aes-128-cbc` over that byte string with the
///    Zepp key and IV.
///
/// If the Dart implementation drifts from either, Zepp gets a payload it cannot
/// decrypt or a password with the wrong characters in it, and the only symptom
/// would be a sign-in that fails for no visible reason.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/pairing/zepp_crypto.dart';
import 'package:healthee/data/pairing/zepp_endpoints.dart';

/// Deliberately awkward: the five characters where Python's `quote_plus` and
/// Dart's `Uri.encodeQueryComponent` disagree, a space, the four characters
/// Python leaves literal, and a non-ASCII letter.
const String _awkwardPassword = "p a!s*s'w(o)rd~_.-é";

const String _pythonEncoded =
    'emailOrPhone=owner%2Btest%40example.com'
    '&state=REDIRECTION'
    '&client_id=HuaMi'
    '&password=p+a%21s%2As%27w%28o%29rd~_.-%C3%A9'
    '&redirect_uri=https%3A%2F%2Fs3-us-west-2.amazonaws.com'
    '%2Fhm-registration%2Fsuccesssignin.html'
    '&region=us-west-2'
    '&token=access'
    '&token=refresh'
    '&country_code=US';

/// `openssl enc -aes-128-cbc -K <"xeNtBVqzDc6tuNTh" hex> -iv <"MAAAYAAAAAAAAABg" hex>`
/// over [_pythonEncoded]. 270 plaintext bytes → 272 with PKCS#7.
const String _opensslCiphertextHex =
    '815932a2f5d6cd860efe3cef4a004fda1c59eee58fce5a6ef1722ec410eb032f'
    '0bb23d6c552f0f5d52c89b775bef7718a51b68bd4b0dfd84c6b14237622a6dca'
    'c969c6620e9fcbee7d14d3a49daf82a0735ace3d97b6dc70811b273c3ac46410'
    '2a3f85981022335a3ffd41fca81d3ef860e9257bdd8ea01d3023d1d1c7745053'
    '818a2a09cbe95e267bb2a7c5f7f31a2cd5f78a1b7cb73208955359fed6c691e3'
    '3f28efe171b0508a7c528219da81740d738a16636cd52196712e4603d336b1bd'
    '9f34eb07bb4f5dc9772693820baac1c1ac4c668fadd29e83027d4a903808542b'
    '5a3d74dd75b3a622641014ba172ce4b8f3f34fbd3941a9482e3d170e63f71a41'
    '45c1a9386f8611f9e679330052ad91f8';

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('encodeForm matches Python byte for byte', () {
    test('the whole step-1 payload, including the repeated token key', () {
      final encoded = encodeForm(
        ZeppForms.tokens(
          email: 'owner+test@example.com',
          password: _awkwardPassword,
        ),
      );

      expect(utf8.decode(encoded), _pythonEncoded);
    });

    test('punctuation is escaped exactly as quote_plus escapes it', () {
      // The five characters an educated guess says the two libraries disagree
      // on. Measured: they do not. This assertion is what keeps that measured
      // rather than remembered.
      expect(
        utf8.decode(encodeForm([('password', "!*'()")])),
        'password=%21%2A%27%28%29',
      );
      // …and the four Python leaves literal stay literal here too.
      expect(utf8.decode(encodeForm([('password', '~_.-')])), 'password=~_.-');
    });

    test('a space is a plus, not %20', () {
      expect(utf8.decode(encodeForm([('a', 'b c')])), 'a=b+c');
    });

    test('non-ASCII goes out as UTF-8 percent-escapes', () {
      expect(utf8.decode(encodeForm([('a', 'é')])), 'a=%C3%A9');
    });

    test('field order is preserved, because it is part of the wire format', () {
      final fields = ZeppForms.tokens(email: 'e', password: 'p');

      expect(fields.map((field) => field.$1).toList(), [
        'emailOrPhone',
        'state',
        'client_id',
        'password',
        'redirect_uri',
        'region',
        'token',
        'token',
        'country_code',
      ]);
    });
  });

  group('encryptZeppPayload matches openssl', () {
    test('AES-128-CBC/PKCS7 with the Zepp key and IV', () {
      final ciphertext = encryptZeppPayload(
        Uint8List.fromList(utf8.encode(_pythonEncoded)),
        key: ZeppCipher.key,
        iv: ZeppCipher.iv,
      );

      expect(_hex(ciphertext), _opensslCiphertextHex);
      // PKCS#7 always pads, so 270 bytes becomes 272 rather than 270.
      expect(ciphertext.length, 272);
    });

    test('a whole-block plaintext still gains a full block of padding', () {
      final ciphertext = encryptZeppPayload(
        Uint8List.fromList(utf8.encode('0123456789abcdef')),
        key: ZeppCipher.key,
        iv: ZeppCipher.iv,
      );

      expect(ciphertext.length, 32);
    });

    test('the key and IV are the 16-byte Zepp constants', () {
      expect(ZeppCipher.key.length, 16);
      expect(ZeppCipher.iv.length, 16);
      expect(utf8.decode(ZeppCipher.key), 'xeNtBVqzDc6tuNTh');
      expect(utf8.decode(ZeppCipher.iv), 'MAAAYAAAAAAAAABg');
    });

    test('a wrong-length key is refused rather than quietly misused', () {
      expect(
        () => encryptZeppPayload(
          Uint8List(16),
          key: Uint8List(8),
          iv: ZeppCipher.iv,
        ),
        throwsArgumentError,
      );
      expect(
        () => encryptZeppPayload(
          Uint8List(16),
          key: ZeppCipher.key,
          iv: Uint8List(8),
        ),
        throwsArgumentError,
      );
    });
  });
}
