/// **Spec-derived** for the curve constants; **structural** for the group law.
///
/// The handshake doc publishes the B-163 parameters as little-endian `uint32[6]`
/// words, and this file re-types them from that document — NOT from
/// `ecdh_sect163k1.dart`. Two of them are then used as an independent check:
///
///  * The base point G is fed in as a *remote* public key. `generateShared`
///    validates a remote point against the curve equation, which uses `coeff_b`
///    and the reduction polynomial — so G validating proves those three
///    constants agree with the published ones.
///  * `k·G` computed through `generateShared(k, G_from_the_doc)` must equal the
///    public key `generateKeypair(k)` produces from the constants held INSIDE
///    the class. A mistyped `base_x` or `base_y` in `lib/` fails here, and only
///    here — every symmetry test below would still pass on the wrong curve.
///
/// The remaining tests are the legacy suite, carried across: they check that
/// the group law is self-consistent (`shared(a, B) == shared(b, A)`), which is
/// the property the handshake actually depends on.
///
/// Not covered by anything here: a known-answer vector from a second
/// implementation. Gadgetbridge's Java and HelioCore's Swift are the two that
/// exist, and neither is in this repo. The owner's strap is the only thing that
/// can settle it, and if the curve were wrong the handshake would fail closed —
/// status `0x25`, not a bad number.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/crypto/ecdh_sect163k1.dart';

/// Verbatim from `research/protocol/zeppos_ble_handshake.md`, § "B-163 curve
/// parameters" — little-endian uint32 words, w0 first.
const List<int> _baseXWords = [
  0xe8343e36,
  0xd4994637,
  0xa0991168,
  0x86a2d57e,
  0xf0eba162,
  0x00000003,
];
const List<int> _baseYWords = [
  0x797324f1,
  0xb11c5c0c,
  0xa2cdd545,
  0x71a0094f,
  0xd51fbc6c,
  0x00000000,
];

/// The 24-byte little-endian encoding of a 6-word field element — the same
/// layout `generateShared` expects for each half of a public key.
Uint8List _bytesOf(List<int> words) {
  final out = Uint8List(24);
  for (var i = 0; i < 24; i++) {
    out[i] = (words[i ~/ 4] >> ((i % 4) * 8)) & 0xFF;
  }
  return out;
}

/// The published base point, encoded as a 48-byte public key `x ‖ y`.
Uint8List _basePointFromTheDoc() => Uint8List(48)
  ..setRange(0, 24, _bytesOf(_baseXWords))
  ..setRange(24, 48, _bytesOf(_baseYWords));

Uint8List _fixed(int seed) =>
    Uint8List.fromList(List<int>.generate(24, (i) => (i * seed + 7) & 0xFF));

void main() {
  group('the curve constants match the published ones', () {
    test('the published base point validates as on-curve', () {
      // generateShared rejects a point that fails y² + xy = x³ + x² + b, so
      // this exercises coeff_b and the reduction polynomial together.
      expect(
        () => EcdhSect163k1.generateShared(_fixed(11), _basePointFromTheDoc()),
        returnsNormally,
      );
    });

    test('k·G through the published G equals the public key for k', () {
      // The left side uses the doc's base point; the right side uses the one
      // compiled into the class. A mistyped word in either fails this and
      // nothing else.
      final priv = _fixed(11);
      final viaDoc = EcdhSect163k1.generateShared(priv, _basePointFromTheDoc());
      final (_, viaClass) = EcdhSect163k1.generateKeypair(
        privateKeyBytes: priv,
      );
      expect(viaDoc, equals(viaClass));
    });

    test('a point that is not on the curve is refused', () {
      final bogus = Uint8List(48)..[0] = 0x01;
      expect(
        () => EcdhSect163k1.generateShared(_fixed(11), bogus),
        throwsArgumentError,
      );
      expect(
        () => EcdhSect163k1.generateShared(_fixed(11), Uint8List(48)),
        throwsArgumentError,
      );
    });
  });

  group('sect163k1 ECDH (the legacy suite, carried across)', () {
    test('keypair has correct sizes', () {
      final (priv, pub) = EcdhSect163k1.generateKeypair(
        privateKeyBytes: _fixed(7),
      );
      expect(priv.length, 24);
      expect(pub.length, 48);
    });

    test('deterministic: same private key -> same public key', () {
      final (_, pub1) = EcdhSect163k1.generateKeypair(
        privateKeyBytes: _fixed(11),
      );
      final (_, pub2) = EcdhSect163k1.generateKeypair(
        privateKeyBytes: _fixed(11),
      );
      expect(pub1, equals(pub2));
    });

    test('ECDH symmetry: shared(a, B) == shared(b, A)', () {
      final (privA, pubA) = EcdhSect163k1.generateKeypair(
        privateKeyBytes: _fixed(11),
      );
      final (privB, pubB) = EcdhSect163k1.generateKeypair(
        privateKeyBytes: _fixed(29),
      );
      expect(
        EcdhSect163k1.generateShared(privA, pubB),
        equals(EcdhSect163k1.generateShared(privB, pubA)),
        reason: 'binary-field point math is wrong if these differ',
      );
    });

    test('random keypairs also produce symmetric shared secrets', () {
      final (privA, pubA) = EcdhSect163k1.generateKeypair();
      final (privB, pubB) = EcdhSect163k1.generateKeypair();
      expect(
        EcdhSect163k1.generateShared(privA, pubB),
        equals(EcdhSect163k1.generateShared(privB, pubA)),
      );
    });

    test('two random keypairs differ — the RNG is actually used', () {
      final (_, pub1) = EcdhSect163k1.generateKeypair();
      final (_, pub2) = EcdhSect163k1.generateKeypair();
      expect(pub1, isNot(equals(pub2)));
    });

    test('a private key too small to be safe is refused, not silently used', () {
      expect(
        () => EcdhSect163k1.generateKeypair(privateKeyBytes: Uint8List(24)),
        throwsArgumentError,
      );
    });

    test('wrong key sizes are refused', () {
      expect(
        () => EcdhSect163k1.generateShared(Uint8List(23), Uint8List(48)),
        throwsArgumentError,
      );
      expect(
        () => EcdhSect163k1.generateShared(Uint8List(24), Uint8List(47)),
        throwsArgumentError,
      );
    });
  });
}
