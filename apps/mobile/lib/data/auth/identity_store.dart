/// Where the Supabase session lives on this phone: the platform keystore.
///
/// `gotrue` persists a session through a [GotrueAsyncStorage] it is handed, and
/// it defaults to none at all — a client with no storage signs the owner out
/// every time the process dies. `supabase_flutter` supplies one backed by
/// `SharedPreferences`, which is the reason this app does not use that package:
/// **a refresh token is a long-lived credential**, it is what lets a stolen
/// phone stay signed in, and `SharedPreferences` is a plaintext file in the
/// app's own data directory.
///
/// So the session goes where every other owner secret in this app goes — the iOS
/// Keychain and the Android Keystore, through the same [SecretStore] the strap's
/// AUTHKEY and the server session already use. One rule, one place, one thing to
/// get right.
///
/// ## What is stored
///
/// Whatever `gotrue` hands over: a JSON blob holding the access token, the
/// refresh token and their expiry. This class does not parse it and must not —
/// the shape is the library's, and a client that read fields out of it would
/// break silently on a version bump. It is an opaque string to us.
///
/// **Nothing here is logged.** Not the value, not its length, not a hash of it.
library;

import 'package:gotrue/gotrue.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:meta/meta.dart';

/// The keystore key the Supabase session is written under.
///
/// Named beside `Credentials`' own keys rather than inside it: `Credentials` is
/// the app's own secrets, and this one is written and read by `gotrue`, which
/// owns both its schedule and its contents. Two writers on one key is how a
/// keystore value becomes a race.
const String kIdentitySessionKey = 'supabase_session';

/// [GotrueAsyncStorage] over the platform keystore.
@immutable
class KeystoreIdentityStore extends GotrueAsyncStorage {
  /// Wraps the app's [SecretStore].
  const KeystoreIdentityStore(this._secrets);

  final SecretStore _secrets;

  @override
  Future<String?> getItem({required String key}) =>
      _secrets.read(key: _scoped(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secrets.write(key: _scoped(key), value: value);

  @override
  Future<void> removeItem({required String key}) =>
      _secrets.delete(key: _scoped(key));

  /// `gotrue` picks its own key names and may change them; ours are a namespace
  /// under one prefix so a rename upstream cannot collide with `Credentials`'
  /// keys, and so `Credentials.clear()` has a prefix to sweep.
  static String _scoped(String key) => '$kIdentitySessionKey.$key';
}
