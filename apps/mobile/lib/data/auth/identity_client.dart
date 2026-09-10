/// Signing in to Supabase, staying signed in, and handing out the access token.
///
/// Supabase is this product's identity provider and nothing else. It signs an
/// access JWT; `apps/server` verifies it and provisions the owner. Nothing in
/// this app touches Supabase's database, storage, realtime or functions, which
/// is why the dependency is `gotrue` — the auth client alone — rather than
/// `supabase_flutter` and its twenty-three transitive packages.
///
/// ## The two credentials, and why there are two
///
/// A Supabase access token lives about an hour. Background BLE sync runs on a
/// phone that has been asleep for six, so the JWT cannot be what `/ingest/*`
/// accepts (MULTI_USER.md §4.3). The server mints a long-lived **device token**
/// for that, once, at sign-in.
///
///   * `/api/*`   → the JWT from here, refreshed on demand
///   * `/ingest/*` → the device token, from the keystore
///
/// They are not interchangeable and must not be: the JWT says who is using the
/// app right now, the device token says which device may write to one owner's
/// history until that owner revokes it.
///
/// ## Persistence is ours, deliberately
///
/// `gotrue` does not persist a session — that is the layer `supabase_flutter`
/// adds, backed by `SharedPreferences`. A refresh token is what keeps a stolen
/// phone signed in, and `SharedPreferences` is a plaintext file in the app's own
/// data directory, so this class does the persisting itself and puts it in the
/// platform keystore beside every other owner secret. See `identity_store.dart`.
///
/// ## Nothing here is logged
///
/// Not the tokens, not the password, not the email. `AuthException.message` is
/// the library's own string about an HTTP status; it is mapped to one of this
/// app's named failures and the failure's `code` is what reaches a log line.
library;

import 'dart:async';
import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:healthee/data/api/signin_failure.dart';
import 'package:healthee/data/auth/identity_failure_mapping.dart';
import 'package:healthee/data/auth/identity_store.dart';

/// Signs in, stays signed in, and answers "what is the current access token?".
class IdentityClient {
  /// The configured `gotrue` client, then the keystore to persist it in.
  ///
  /// Positional and private, the same shape as `ServerSessionInterceptor`'s:
  /// making them public named fields would put `GoTrueClient` on this class's
  /// surface, and being the ONE place that touches it is the whole point.
  IdentityClient(this._auth, this._secrets);

  final GoTrueClient _auth;
  final SecretStore _secrets;
  StreamSubscription<AuthState>? _watch;
  Future<void>? _ready;

  /// The signed-in owner's Supabase UUID, or null when signed out.
  String? get userId => _auth.currentSession?.user.id;

  /// True when a session is held — expired or not.
  ///
  /// Expiry is deliberately not consulted: an expired access token with a live
  /// refresh token IS a session, and reporting it as signed out would send the
  /// owner back to a form they do not need to fill in.
  ///
  /// ⚠ Only meaningful after [restore] has completed. Call [accessToken] first,
  /// or await [restore] — on a cold start this reads false until the keystore
  /// has been consulted, which is a different claim from "signed out".
  bool get isSignedIn => _auth.currentSession != null;

  /// Reads the stored session back, once, and starts persisting future ones.
  ///
  /// **Memoised, and awaited by everything that needs an answer.** There is no
  /// start-up hook to forget to call: the first thing to ask for a token waits
  /// for this, and every later caller gets the same completed future. A restore
  /// bolted onto `main` instead would be a race — the first `/api/*` request of
  /// a cold start would read "signed out" and fall back to a credential the
  /// owner had already replaced.
  Future<void> restore() => _ready ??= _restore();

  /// The real work, run once behind [restore].
  ///
  /// A stored session that will not parse is DELETED rather than kept: it
  /// cannot be refreshed, so keeping it only makes every later read fail the
  /// same way, and the owner's route out is the sign-in screen either way.
  Future<void> _restore() async {
    _watch ??= _auth.onAuthStateChange.listen(_persist, onError: _noteStreamError);
    final stored = await _secrets.read(key: kIdentitySessionKey);
    if (stored == null) return;
    try {
      await _auth.recoverSession(stored);
    } on AuthException catch (error) {
      // The code, never the message: it can quote the response body.
      AppLog.info('identity', 'stored session not recoverable (${error.code})');
      await _secrets.delete(key: kIdentitySessionKey);
    } on FormatException {
      AppLog.info('identity', 'stored session is not readable; discarding it');
      await _secrets.delete(key: kIdentitySessionKey);
    }
  }

  /// Signs in with an email and a password. Throws [ServerSignInException].
  Future<void> signIn({required String email, required String password}) async {
    // Before anything else, so the auth-state listener is live and the session
    // this produces is persisted rather than held only in memory.
    await restore();
    await _guarded(
      () => _auth.signInWithPassword(email: email, password: password),
      creating: false,
    );
  }

  /// Creates an account. Throws [ServerSignInException].
  ///
  /// A project with email confirmation switched on returns **no session** here,
  /// which is not a failure and must not be reported as one — the owner has an
  /// account and a mail to open. [IdentityNeedsConfirmation] says exactly that.
  Future<void> signUp({required String email, required String password}) async {
    await restore();
    final response = await _guarded(
      () => _auth.signUp(email: email, password: password),
      creating: true,
    );
    if (response.session == null) {
      throw const ServerSignInException(IdentityNeedsConfirmation());
    }
  }

  /// The current access token, refreshed if it has expired. Null when signed out.
  ///
  /// `getSession` de-duplicates concurrent refreshes inside `gotrue`, so the
  /// four screens that all load at once spend one refresh token between them
  /// rather than racing to spend it four times — which would invalidate the
  /// rotated token for the three that lost.
  Future<String?> accessToken() async {
    await restore();
    try {
      return (await _auth.getSession())?.accessToken;
    } on AuthException catch (error) {
      // A refresh that cannot succeed is a session that is over. Say so once,
      // and let the caller's 401 handling take the owner to sign-in.
      AppLog.info('identity', 'the session could not be refreshed (${error.code})');
      return null;
    }
  }

  /// Signs out locally and forgets the stored session.
  ///
  /// `SignOutScope.local` on purpose: this phone stops being signed in, and the
  /// owner's other devices are not touched. Signing out of a laptop because a
  /// phone was signed out is a surprise, and the way to end every session
  /// deliberately is to revoke the device tokens, which is its own control.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (error) {
      // The server-side revoke can fail; the local session must still go. An
      // owner who pressed sign out and stayed signed in has been ignored.
      AppLog.info('identity', 'remote sign-out failed (${error.code})');
    }
    await _secrets.delete(key: kIdentitySessionKey);
  }

  /// Stops watching. The client stays usable; nothing new is persisted.
  Future<void> dispose() async {
    await _watch?.cancel();
    _watch = null;
  }

  /// Notes an error `gotrue` put on the auth-state stream, and swallows it.
  ///
  /// **Swallowed deliberately, and this is the one place it is right.** The
  /// stream carries notifications, not results: every operation that can fail
  /// already reports its failure to the caller that asked for it — a refused
  /// sign-in throws, a dead refresh makes [accessToken] return null. What
  /// arrives here is the same event a second time, with nobody waiting for it,
  /// and an unhandled error on a broadcast stream takes the isolate down.
  ///
  /// The type, never the object: an `AuthException` can quote a response body.
  void _noteStreamError(Object error) {
    AppLog.info('identity', 'auth stream reported ${error.runtimeType}');
  }

  /// Writes the session on every change `gotrue` reports, including refreshes.
  ///
  /// Keyed off the STREAM rather than off the sign-in call, because the token
  /// that matters most is the one a background refresh produced: a refresh
  /// persisted only by the code path that asked for it would leave the phone
  /// holding a spent refresh token after the process died mid-cycle.
  Future<void> _persist(AuthState state) async {
    final session = state.session;
    if (session == null) {
      await _secrets.delete(key: kIdentitySessionKey);
      return;
    }
    await _secrets.write(
      key: kIdentitySessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  /// Runs [call] and turns `gotrue`'s exceptions into this app's named failures.
  Future<AuthResponse> _guarded(
    Future<AuthResponse> Function() call, {
    required bool creating,
  }) async {
    try {
      return await call();
    } on AuthRetryableFetchException catch (error) {
      // ⛔ **This clause must come BEFORE `on AuthException`**, which it extends.
      // Without it a dead connection to the identity provider was caught as a
      // refusal and reported as one — the exact inversion `signin_failure.dart`
      // exists to prevent, and it cost a real afternoon: an ISP hijacking DNS
      // for the provider's domain produced "that account could not be created",
      // which sent the owner to check an account that was never the problem.
      //
      // `gotrue` raises this for a transport failure AND for a 5xx, and both are
      // "it did not answer" from here: neither says anything about the
      // credentials, and both are worth retrying, which is what separates this
      // from every other case in the taxonomy.
      AppLog.info(
        'identity',
        '${creating ? 'sign-up' : 'sign-in'} could not reach the provider '
            '(${error.statusCode ?? 'no response'})',
      );
      throw const ServerSignInException(IdentityUnreachable());
    } on AuthException catch (error) {
      // The code reaches the log as well as the screen. Without this line the
      // provider's own reason existed nowhere an operator could read it, and a
      // failure this app has no case for was indistinguishable from one it does.
      AppLog.info(
        'identity',
        '${creating ? 'sign-up' : 'sign-in'} refused (${error.code})',
      );
      throw ServerSignInException(identityFailure(error, creating: creating));
    } on Object catch (error) {
      // Anything that is not an `AuthException` never reached the auth server:
      // a socket, a DNS answer, a TLS handshake. Reported as unreachable rather
      // than as a refusal, which is the distinction `signin_failure.dart` exists
      // to keep — "your password is wrong" for a dead network sends the owner to
      // change a password that was correct.
      AppLog.info('identity', 'the identity provider did not answer: ${error.runtimeType}');
      throw const ServerSignInException(IdentityUnreachable());
    }
  }
}
