/// Per-owner secrets, in the platform keystore. Never in a dart-define.
///
/// The three values here are what `core/env.dart` explains at length must NOT be
/// compiled in: the API bearer token, the strap's MAC address, and the pairing
/// AUTHKEY. All three come from the owner's Zepp account at pairing time, all
/// three are per-owner, and baking them into the binary is what made the legacy
/// app single-owner.
///
/// `flutter_secure_storage` puts them in the iOS Keychain and the Android
/// EncryptedSharedPreferences/Keystore, which is where a credential belongs — not
/// in `SharedPreferences`, and not in the drift database beside cached payloads
/// (a cache is something we are willing to delete and re-fetch; a pairing key is
/// not).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'credentials.g.dart';

/// Reads and writes the owner's secrets.
///
/// One class so the key strings exist once. A second module spelling
/// `'helio_token'` slightly differently would not fail — it would just read null,
/// and the app would look signed out.
class Credentials {
  /// Wraps a secure-storage backend. Inject a fake in tests.
  const Credentials(this._storage);

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'helio_token';
  static const String _strapMacKey = 'strap_mac';
  static const String _strapAuthKeyKey = 'strap_auth_key';

  /// The API bearer token, or null when the owner has not signed in.
  Future<String?> apiToken() => _storage.read(key: _tokenKey);

  /// Stores the API bearer token.
  Future<void> setApiToken(String token) => _storage.write(key: _tokenKey, value: token);

  /// The paired strap's Bluetooth MAC, or null when nothing is paired.
  Future<String?> strapMac() => _storage.read(key: _strapMacKey);

  /// The paired strap's AUTHKEY, or null when nothing is paired.
  Future<String?> strapAuthKey() => _storage.read(key: _strapAuthKeyKey);

  /// Stores a strap pairing. Both halves are written together because half a
  /// pairing is not a state the BLE layer can do anything with.
  Future<void> setStrapPairing({required String mac, required String authKey}) async {
    await _storage.write(key: _strapMacKey, value: mac);
    await _storage.write(key: _strapAuthKeyKey, value: authKey);
  }

  /// Forgets everything. Sign-out, and the first step of re-pairing.
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _strapMacKey);
    await _storage.delete(key: _strapAuthKeyKey);
  }
}

/// The app's one [Credentials] instance.
@Riverpod(keepAlive: true)
Credentials credentials(Ref ref) {
  return const Credentials(
    FlutterSecureStorage(
      // Android encrypts by default in v10 (the old `encryptedSharedPreferences`
      // flag is deprecated and ignored). `first_unlock` on iOS so a background
      // sync after a reboot can still read the token, without allowing access
      // while the device is locked for the first time.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
}
