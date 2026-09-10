/// A real [IdentityClient] over a scripted auth server.
///
/// **A real one, not a fake.** `IdentityClient` is thin on purpose and almost
/// everything worth asserting about it is what it does WITH `gotrue` — when it
/// persists, what it does with an unparseable stored session, which exception
/// becomes which named failure. A hand-written double would assert that the
/// double behaves as written, which is the shape of test that passes while the
/// real thing is broken.
///
/// `GoTrueClient` takes a `package:http` client, so the auth server is scripted
/// at the transport and every layer above it is the shipping code.
library;

import 'dart:convert';

import 'package:gotrue/gotrue.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:healthee/data/auth/identity_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The Supabase project a test signs in to. Never reached.
const String kAuthUrl = 'https://project.supabase.co/auth/v1';

/// A test access token, valid for an hour.
///
/// **JWT-SHAPED, and that is load-bearing.** `Session.expiresAt` is decoded from
/// the access token's own `exp` claim and NOT from the `expires_at` field of the
/// JSON around it — so a token that is not a JWT decodes to a null expiry, and
/// `isExpired` answers false forever. A fixture using an opaque string would
/// make every session immortal and quietly disable the refresh path this app
/// depends on.
///
/// The signature is nonsense on purpose: this app never verifies it. The SERVER
/// does, against `SUPABASE_JWT_SECRET`, and that is proved on the server side.
final String kAccessToken = jwtExpiringIn(const Duration(hours: 1));

/// A JWT-shaped token whose `exp` is [ahead] from now. Negative is in the past.
String jwtExpiringIn(Duration ahead) {
  String segment(Map<String, Object?> claims) => base64Url
      .encode(utf8.encode(jsonEncode(claims)))
      .replaceAll('=', '');
  final exp = DateTime.now().add(ahead).millisecondsSinceEpoch ~/ 1000;
  return '${segment(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})}'
      '.${segment(<String, Object?>{'sub': kUserId, 'exp': exp})}'
      '.not-a-real-signature';
}

/// Its refresh token.
const String kRefreshToken = 'test-refresh-token-bbb222';

/// The owner behind both.
const String kUserId = '11111111-2222-3333-4444-555555555555';

/// A `gotrue` token response for [access], expiring [inSeconds] from now.
Map<String, Object?> tokenBody({
  String? access,
  String refresh = kRefreshToken,
  int inSeconds = 3600,
}) => <String, Object?>{
  'access_token': access ?? kAccessToken,
  'token_type': 'bearer',
  'expires_in': inSeconds,
  'refresh_token': refresh,
  'user': <String, Object?>{
    'id': kUserId,
    'aud': 'authenticated',
    'email': 'owner@example.com',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-01-01T00:00:00Z',
  },
};

/// A scripted auth server: what it answered, and what it was asked.
class ScriptedAuth {
  /// [reply] answers every request; [status] is its HTTP status.
  ScriptedAuth({Map<String, Object?>? reply, this.status = 200})
    : reply = reply ?? tokenBody();

  /// The body to answer with.
  final Map<String, Object?> reply;

  /// The status to answer with.
  final int status;

  /// Every request this server was sent, in order.
  final List<http.Request> sent = <http.Request>[];

  /// The transport `GoTrueClient` should be given.
  MockClient get client => MockClient((request) async {
    sent.add(request);
    return http.Response(
      jsonEncode(reply),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });
}

/// An [IdentityClient] over [auth] and [secrets], configured as the app's is.
IdentityClient identityWith(ScriptedAuth auth, SecretStore secrets) {
  return IdentityClient(
    GoTrueClient(
      url: kAuthUrl,
      headers: const <String, String>{'apikey': 'test-anon-key'},
      httpClient: auth.client,
      // Off in tests, and ONLY in tests: the refresh timer is a real
      // `Timer.periodic` and a widget test's fake clock never fires it, while a
      // unit test's real one leaves a pending timer the framework fails on.
      // What the timer does is proved by asking for an expired token instead.
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    ),
    secrets,
  );
}
