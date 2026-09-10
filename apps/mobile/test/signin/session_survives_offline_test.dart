/// ⛔ A network failure must never delete the owner's session.
///
/// ## The bug this closes, and what it cost
///
/// `AuthRetryableFetchException extends AuthException`, so a single `on
/// AuthException` clause catches an unreachable server and a refused credential
/// together. `IdentityClient._restore` had exactly that, and its handler deleted
/// the stored session.
///
/// The consequence was not a bad error message. **One unreachable call at app
/// start signed the owner out permanently** — a train, a captive portal, an ISP
/// resolving the name to its own server. Nothing said so. `accessToken()` then
/// returned null forever, `ServerSessionInterceptor` correctly sent no header at
/// all rather than a credential that cannot work, and every `/api/*` call came
/// back 401 while Today showed a loading state over a session that no longer
/// existed. Observed in production on 2026-09-10: 1,280 requests in four minutes,
/// every one a 401, and not one of them carrying a token for the server to reject.
///
/// The rule these tests hold: **delete a credential only when the server has told
/// us it is dead.** Not being able to ask is not an answer.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/auth/identity_store.dart';

import '../pairing/_pairing_fakes.dart';
import '_identity_fakes.dart';

/// A stored session whose access token has already expired, so recovering it has
/// to reach the network — which is the only way to fail the way this is about.
String _expiredSession() => jsonEncode(<String, Object?>{
  'access_token': jwtExpiringIn(const Duration(hours: -1)),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': kRefreshToken,
  'user': <String, Object?>{
    'id': kUserId,
    'aud': 'authenticated',
    'email': 'owner@example.com',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-01-01T00:00:00Z',
  },
});

void main() {
  test('AN UNREACHABLE SERVER LEAVES THE STORED SESSION EXACTLY WHERE IT WAS', () async {
    final store = FakeSecretStore()
      ..values[kIdentitySessionKey] = _expiredSession();
    final auth = ScriptedAuth(unreachable: true);

    await identityWith(auth, store, autoRefresh: true).restore();

    // The load-bearing assertion. Before the fix this key was gone, and with it
    // the owner's only way back in short of typing a password again.
    expect(
      store.values[kIdentitySessionKey],
      isNotNull,
      reason: 'a session we could not ASK about must not be thrown away',
    );
    expect(auth.sent, isNotEmpty, reason: 'the premise: it did try');
  });

  test('and the next attempt actually retries rather than reusing the failure', () async {
    // `restore()` memoises, so a transient failure that stayed memoised would
    // make the whole process' remaining life behave as signed out — the network
    // could come back and nothing would notice until the app was killed.
    final store = FakeSecretStore()
      ..values[kIdentitySessionKey] = _expiredSession();
    final auth = ScriptedAuth(unreachable: true);
    final identity = identityWith(auth, store, autoRefresh: true);

    await identity.restore();
    final afterFirst = auth.sent.length;
    await identity.restore();

    expect(
      auth.sent.length,
      greaterThan(afterFirst),
      reason: 'the second restore was handed the memoised failure',
    );
  });

  test('a sign-in after a failed restore still yields a token', () async {
    // The property the retry above has to not break. Clearing `_ready` means the
    // NEXT caller re-runs recovery — and `accessToken` is a caller, so `signIn`
    // (which awaits `restore`) is followed immediately by a second recovery
    // attempt while a fresh session is live.
    //
    // ⚠ This test does NOT distinguish a guard in `_restore`: `gotrue` already
    // returns the existing session rather than recovering over it when one is
    // live and unexpired for the same user (`gotrue_client.dart`, "Session was
    // already refreshed elsewhere"). A guard here was written, could not be
    // caught by any mutation, and was removed. What this holds is the OUTCOME —
    // that the sequence yields a usable token — which is what the owner
    // experiences and what stays true if that upstream behaviour changes.
    //
    // The refresh is what cannot get through, while a password sign-in to the
    // same host works: the owner's ordinary condition on a flaky link, and the
    // condition the retry exists for.
    final store = FakeSecretStore()
      ..values[kIdentitySessionKey] = _expiredSession();
    final auth = ScriptedAuth(unreachableGrant: 'refresh_token');
    final identity = identityWith(auth, store, autoRefresh: true);

    await identity.restore(); // the refresh cannot get through; memo cleared
    await identity.signIn(email: 'owner@example.com', password: 'a-password');

    expect(await identity.accessToken(), isNotNull);
  });

  test('A REFUSED session IS still deleted — the distinction is the point', () async {
    // The other half. A server that answers "this refresh token is dead" HAS
    // told us, and keeping it would make every later read fail the same way with
    // no route out. Only the unanswerable case is kept.
    final store = FakeSecretStore()
      ..values[kIdentitySessionKey] = _expiredSession();
    final auth = ScriptedAuth(
      status: 400,
      reply: const <String, Object?>{
        'error': 'invalid_grant',
        'error_description': 'Invalid Refresh Token',
      },
    );

    await identityWith(auth, store, autoRefresh: true).restore();

    expect(store.values.containsKey(kIdentitySessionKey), isFalse);
  });
}
