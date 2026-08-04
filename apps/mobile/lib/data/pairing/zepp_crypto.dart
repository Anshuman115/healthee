/// Step 1's payload: url-encode, then AES-CBC/PKCS7 encrypt.
///
/// Two pure functions over bytes, with no logging, no I/O and no state. That is
/// deliberate — this is the one place in the app that handles a plaintext
/// password, and the smallest possible surface is the point. It is also what
/// makes both halves unit-testable against fixtures rather than against Zepp.
///
/// ## The encoder was checked against Python, not assumed to match it
///
/// The reference builds this body with `urllib.parse.urlencode(..., doseq=True)`,
/// which is `quote_plus`: space to `+`, everything outside `A-Za-z0-9_.-~`
/// percent-escaped. `Uri.encodeQueryComponent` was **measured** against it rather
/// than trusted — a password is not a good place to assume two standard
/// libraries agree — and it matches, including the five characters (`!*'()`)
/// where an educated guess would have said they differ.
///
/// So the encoder here is Dart's, and the golden in `zepp_crypto_test.dart` is
/// Python's actual output over an awkward password. That test is not redundant
/// with this comment: the agreement is a property of two libraries that can
/// drift, and it is the kind of drift whose only symptom is a sign-in that
/// stops working for the people whose passwords contain punctuation.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Url-encodes ordered form [fields] the way Python's `urlencode` does.
///
/// Pairs rather than a map because `token` legitimately appears twice in step
/// 1's body, and because the order is part of what Zepp is fed.
Uint8List encodeForm(List<(String, String)> fields) {
  final body = fields
      .map(
        (field) => '${Uri.encodeQueryComponent(field.$1)}'
            '=${Uri.encodeQueryComponent(field.$2)}',
      )
      .join('&');
  // Percent-encoding has already reduced everything to ASCII, so this cannot
  // re-introduce a multi-byte sequence.
  return Uint8List.fromList(ascii.encode(body));
}

/// AES-128-CBC with PKCS#7 padding, as `huami_token.helpers.zepp_encrypt_payload`.
///
/// [key] and [iv] are the fixed Zepp constants from `zepp_endpoints.dart`; both
/// must be 16 bytes, and a wrong length is an `ArgumentError` here rather than a
/// silent misuse of the cipher.
Uint8List encryptZeppPayload(Uint8List plaintext, {
  required Uint8List key,
  required Uint8List iv,
}) {
  if (key.length != 16) {
    throw ArgumentError.value(key.length, 'key', 'AES-128 needs a 16-byte key');
  }
  if (iv.length != 16) {
    throw ArgumentError.value(iv.length, 'iv', 'CBC needs a 16-byte IV');
  }
  final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
    ..init(
      true,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
        null,
      ),
    );
  return cipher.process(plaintext);
}
