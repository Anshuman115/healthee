/// Both routes into pairing go through `PairedStrap.parse`, so this is where a
/// bad pairing is stopped — before storage, not at the first handshake.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_exception.dart';
import 'package:healthee/data/pairing/pairing_failure.dart';

const String _key = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

MalformedPairingInput rejects({required String mac, required String authKey}) {
  try {
    PairedStrap.parse(mac: mac, authKey: authKey);
  } on PairingException catch (error) {
    return error.failure as MalformedPairingInput;
  }
  fail('expected $mac / $authKey to be rejected');
}

void main() {
  group('normalisation', () {
    test('a lower-case, dash-separated MAC comes back canonical', () {
      final strap = PairedStrap.parse(mac: 'db-98-1f-80-4c-3d', authKey: _key);

      expect(strap.mac, 'DB:98:1F:80:4C:3D');
    });

    test('a 0x prefix and upper-case hex are both accepted', () {
      final strap = PairedStrap.parse(
        mac: 'DB:98:1F:80:4C:3D',
        authKey: '0X${_key.toUpperCase()}',
      );

      expect(strap.authKey, _key);
    });

    test('surrounding whitespace is trimmed, because people paste', () {
      final strap = PairedStrap.parse(
        mac: '  DB:98:1F:80:4C:3D ',
        authKey: ' $_key\n',
      );

      expect(strap.mac, 'DB:98:1F:80:4C:3D');
      expect(strap.authKey, _key);
    });

    test('shortMac is the last two octets and nothing more', () {
      final strap = PairedStrap.parse(mac: 'DB:98:1F:80:4C:3D', authKey: _key);

      expect(strap.shortMac, '4C:3D');
    });
  });

  group('rejection names the field and the shape', () {
    test('a five-octet MAC', () {
      final failure = rejects(mac: 'DB:98:1F:80:4C', authKey: _key);

      expect(failure.field, 'MAC address');
      expect(failure.expected, contains('six pairs of hex digits'));
    });

    test('a MAC with a non-hex digit', () {
      expect(rejects(mac: 'DB:98:1F:80:4C:3G', authKey: _key).field, 'MAC address');
    });

    test('a 31-character key is a different key, not a typo', () {
      final failure = rejects(mac: 'DB:98:1F:80:4C:3D', authKey: _key.substring(1));

      expect(failure.field, 'auth key');
      expect(failure.expected, contains('32 hex digits'));
    });

    test('an empty key', () {
      expect(rejects(mac: 'DB:98:1F:80:4C:3D', authKey: '').field, 'auth key');
    });

    test('a key with non-hex characters', () {
      expect(
        rejects(mac: 'DB:98:1F:80:4C:3D', authKey: 'z' * 32).field,
        'auth key',
      );
    });
  });

  group('the key never prints itself', () {
    test('toString redacts it', () {
      final strap = PairedStrap.parse(mac: 'DB:98:1F:80:4C:3D', authKey: _key);

      expect(strap.toString(), isNot(contains(_key)));
      expect(strap.toString(), contains('<redacted>'));
    });

    test('a PairingException prints only its code', () {
      const exception = PairingException(WrongZeppCredentials());

      expect(exception.toString(), 'PairingException(wrong_zepp_credentials)');
    });
  });
}
