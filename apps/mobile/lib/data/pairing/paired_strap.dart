/// What "paired" means: one MAC and one auth key, both known to be well-formed.
///
/// The type is the validation. Both routes into pairing — the Zepp account and
/// manual entry — construct through [PairedStrap.parse], so a malformed key is
/// rejected at the boundary rather than at the first BLE handshake, where it
/// would look like a protocol bug in code nobody has written yet.
///
/// The 32-hex-character rule is not invented here: `huami_crypto.dart` in the
/// legacy app takes exactly 16 bytes and throws otherwise, and the ECDH
/// handshake XORs the key byte-for-byte against the shared secret. A 31-digit
/// key is not "nearly right", it is a different protocol.
library;

import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';
import 'package:meta/meta.dart';

final RegExp _macPattern = RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$');
final RegExp _hexPattern = RegExp(r'^[0-9a-f]{32}$');

/// A strap we hold credentials for.
@immutable
class PairedStrap {
  /// Prefer [PairedStrap.parse]; this constructor assumes both values are
  /// already normalised and is used when reading them back out of the keystore.
  const PairedStrap({required this.mac, required this.authKey});

  /// Normalises and validates a MAC and an auth key.
  ///
  /// Accepts the shapes a person or an API actually produces: a MAC with `:` or
  /// `-` separators in either case, and a key with or without a `0x` prefix.
  /// Throws [PairingException] with a [MalformedPairingInput] otherwise.
  factory PairedStrap.parse({required String mac, required String authKey}) {
    final normalisedMac = mac.trim().toUpperCase().replaceAll('-', ':');
    if (!_macPattern.hasMatch(normalisedMac)) {
      throw const PairingException(
        MalformedPairingInput(
          field: 'MAC address',
          expected: 'A MAC is six pairs of hex digits, like DB:98:1F:80:4C:3D.',
        ),
      );
    }

    var normalisedKey = authKey.trim().toLowerCase();
    if (normalisedKey.startsWith('0x')) {
      normalisedKey = normalisedKey.substring(2);
    }
    if (!_hexPattern.hasMatch(normalisedKey)) {
      throw const PairingException(
        MalformedPairingInput(
          field: 'auth key',
          expected:
              'The key is exactly 32 hex digits (16 bytes), with or without a '
              '0x in front. Anything shorter is a different key, not a typo we '
              'can fix.',
        ),
      );
    }

    return PairedStrap(mac: normalisedMac, authKey: normalisedKey);
  }

  /// Bluetooth address, upper case, colon-separated: `DB:98:1F:80:4C:3D`.
  final String mac;

  /// The 32-hex-character pairing key, lower case, no `0x` prefix.
  ///
  /// **A device secret.** Treat it exactly as a password: it lives in the
  /// platform keystore, it is never sent to the Healthee API, and it is never
  /// logged. [toString] does not include it and neither may anything else.
  final String authKey;

  /// The MAC's last two octets — enough to tell two straps apart on screen,
  /// and the only part of a pairing that is safe to put in a log line.
  String get shortMac => mac.substring(mac.length - 5);

  @override
  String toString() => 'PairedStrap($mac, authKey: <redacted>)';

  @override
  bool operator ==(Object other) =>
      other is PairedStrap && other.mac == mac && other.authKey == authKey;

  @override
  int get hashCode => Object.hash(mac, authKey);
}
