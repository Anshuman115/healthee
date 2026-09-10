/// Per-owner secrets, in the platform keystore. Never in a dart-define.
///
/// The values here are what `core/env.dart` explains at length must NOT be
/// compiled in: the API bearer token, the strap's MAC address, and the pairing
/// AUTHKEY. The last two come from the owner's Zepp account at pairing time and
/// the first is typed on the sign-in screen; all of them are per-owner, and
/// baking them into the binary is what made the legacy app single-owner.
///
/// ## The server address is stored beside the token, and is not a secret
///
/// [apiBaseUrl] is ordinary configuration. It lives here because it is only
/// meaningful *with* the token — see [setServerSession] — and because a second
/// store is a second thing that can be half-written.
///
/// `flutter_secure_storage` puts them in the iOS Keychain and the Android
/// EncryptedSharedPreferences/Keystore, which is where a credential belongs — not
/// in `SharedPreferences`, and not in the drift database beside cached payloads
/// (a cache is something we are willing to delete and re-fetch; a pairing key is
/// not).
///
/// ## The Zepp email and password are OPTIONAL, and off by default
///
/// [zeppEmail] / [zeppPassword] hold a sign-in the owner explicitly asked us to
/// remember, so re-pairing does not mean typing a password again. Nothing in the
/// app writes them without that opt-in, nothing requires them to be present, and
/// [forgetZeppAccount] is reachable from the pairing screen. They are in the same
/// keystore as everything else here — see `data/pairing/pairing_repository.dart`
/// for the consent wording the screen actually shows.
///
/// The Zepp **app token** is deliberately absent. `data/pairing/zepp_session.dart`
/// explains why: nothing after pairing consumes it, so caching a 30-day bearer
/// credential would be storage with no reader.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:healthee/data/api/stored_server_session.dart';
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

  final SecretStore _storage;

  static const String _sessionKey = 'helio_server_session';
  static const String _tokenKey = 'helio_token';
  static const String _baseUrlKey = 'helio_base_url';
  static const String _strapMacKey = 'strap_mac';
  static const String _strapAuthKeyKey = 'strap_auth_key';
  static const String _zeppEmailKey = 'zepp_email';
  static const String _zeppPasswordKey = 'zepp_password';

  /// The API bearer token, or null when the owner has not signed in.
  Future<String?> apiToken() async => (await serverSession())?.token;

  /// The server that token was accepted by, or null when there is no session.
  ///
  /// Not a secret, and kept here anyway: it is meaningless apart from the token
  /// and must never be half-present. A second store would let the app hold a
  /// token for one server and an address for another, which is a request sent
  /// somewhere it was never authorised.
  Future<String?> apiBaseUrl() async => (await serverSession())?.baseUrl;

  /// Reads ONE snapshot. Old keys are immutable in this version and only used
  /// until the first new-format write. The tombstone prevents sign-out revival.
  Future<StoredServerSession?> serverSession() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded != null) return StoredServerSession.decode(encoded);
    final baseUrl = await _storage.read(key: _baseUrlKey);
    final token = await _storage.read(key: _tokenKey);
    final updated = await _storage.read(key: _sessionKey);
    if (updated != null) return StoredServerSession.decode(updated);
    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return StoredServerSession(
      baseUrl: baseUrl,
      token: token,
      cacheScope: 'legacy',
      // A pre-session-format phone can only be holding the shared token: the
      // device-token mint did not exist when these keys were last written.
      kind: StoredCredentialKind.shared,
    );
  }

  /// Stores a verified server sign-in.
  ///
  /// Both halves together, for the reason [strapMac] gives about pairings: half
  /// a session is not a state any caller can do anything with. **Only
  /// `data/api/server_session.dart` calls this, and only after the server has
  /// answered 200** — storing an unverified token is what makes "signed in"
  /// mean nothing.
  Future<void> setServerSession({
    required String baseUrl,
    required String token,
    required StoredCredentialKind kind,
  }) async {
    final session = StoredServerSession.create(baseUrl, token, kind: kind);
    await _storage.write(key: _sessionKey, value: session.encode());
  }

  /// Drops the server sign-in, leaving the strap pairing alone. Sign-out.
  Future<void> forgetServerSession() async {
    await _storage.write(key: _sessionKey, value: 'null');
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _baseUrlKey);
  }

  /// The paired strap's Bluetooth MAC, or null when nothing is paired.
  Future<String?> strapMac() => _storage.read(key: _strapMacKey);

  /// The paired strap's AUTHKEY, or null when nothing is paired.
  Future<String?> strapAuthKey() => _storage.read(key: _strapAuthKeyKey);

  /// Stores a strap pairing. Both halves are written together because half a
  /// pairing is not a state the BLE layer can do anything with.
  Future<void> setStrapPairing({
    required String mac,
    required String authKey,
  }) async {
    await _storage.write(key: _strapMacKey, value: mac);
    await _storage.write(key: _strapAuthKeyKey, value: authKey);
  }

  /// Drops the strap pairing, leaving any API session alone. Re-pairing starts here.
  Future<void> forgetStrapPairing() async {
    await _storage.delete(key: _strapMacKey);
    await _storage.delete(key: _strapAuthKeyKey);
  }

  /// The remembered Zepp sign-in address, or null when none was kept.
  Future<String?> zeppEmail() => _storage.read(key: _zeppEmailKey);

  /// The remembered Zepp password, or null when none was kept.
  Future<String?> zeppPassword() => _storage.read(key: _zeppPasswordKey);

  /// Remembers a Zepp sign-in. **Only ever called after an explicit opt-in.**
  Future<void> setZeppAccount({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _zeppEmailKey, value: email);
    await _storage.write(key: _zeppPasswordKey, value: password);
  }

  /// Forgets the Zepp sign-in. Called whenever the opt-in is off, including on
  /// every pairing that does not ask for it — so turning the box off once and
  /// pairing again actually removes what an earlier pairing stored.
  Future<void> forgetZeppAccount() async {
    await _storage.delete(key: _zeppEmailKey);
    await _storage.delete(key: _zeppPasswordKey);
  }

  /// Forgets everything: the server session, the strap and any Zepp sign-in.
  Future<void> clear() async {
    await forgetServerSession();
    await forgetStrapPairing();
    await forgetZeppAccount();
  }
}

/// The app's one [Credentials] instance.
/// The app's ONE keystore handle.
///
/// Its own provider because two things now write owner secrets — [Credentials]
/// for the strap, the server session and the Zepp account, and
/// `data/auth/identity_store.dart` for the Supabase session that `gotrue` owns.
/// Two `FlutterSecureStorage` instances with different options is two different
/// keychains on iOS, and a value written under one is simply absent under the
/// other. One handle, one set of options, one place to change them.
@Riverpod(keepAlive: true)
SecretStore secretStore(Ref ref) {
  return const KeystoreSecretStore(
    FlutterSecureStorage(
      // Android encrypts by default in v10 (the old `encryptedSharedPreferences`
      // flag is deprecated and ignored). `first_unlock` on iOS so a background
      // sync after a reboot can still read the token, without allowing access
      // while the device is locked for the first time.
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
}

/// The app's [Credentials], over the shared keystore.
@Riverpod(keepAlive: true)
Credentials credentials(Ref ref) {
  return Credentials(ref.watch(secretStoreProvider));
}
