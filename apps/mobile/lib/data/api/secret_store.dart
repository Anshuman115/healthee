/// The four operations [Credentials] needs from a keystore, and nothing else.
///
/// `flutter_secure_storage`'s own class is a concrete plugin type: reaching it
/// means a platform channel, which a `flutter test` host does not have. A test
/// therefore cannot exercise "what does pairing actually write" against the real
/// class — and "what does pairing write" is the security-relevant question in
/// this whole work package, so it has to be testable.
///
/// Hence a four-method interface we own. The production implementation is a
/// pass-through; the test one is a map. Nothing else in the app widens it: a
/// fifth method here is a fifth thing a fake has to get right.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';

/// A place to keep per-owner secrets.
abstract interface class SecretStore {
  /// The value at [key], or null when nothing is stored.
  Future<String?> read({required String key});

  /// Stores [value] at [key].
  Future<void> write({required String key, required String value});

  /// Removes [key]. A no-op when it is not there.
  Future<void> delete({required String key});
}

/// [SecretStore] backed by the iOS Keychain and the Android Keystore.
@immutable
class KeystoreSecretStore implements SecretStore {
  /// Wraps a configured [FlutterSecureStorage].
  const KeystoreSecretStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
