/// The ONE HTTP client. Every network call in this app goes through it.
///
/// Engineering Standards §3: "single API client via provider". The legacy repo is
/// the argument — a 4,463-line API file grew from per-feature clients, each with
/// its own base URL handling, its own timeout, and its own idea of what an error
/// was. One instance means auth, timeouts and logging are configured once and
/// cannot drift apart, and it means a test overrides one provider to fake the
/// entire network.
///
/// `keepAlive` because a client is a connection pool: rebuilding it per screen
/// would throw away keep-alive sockets and pay a TLS handshake on every tab
/// switch, against a 60 fps budget (Standards §1).
///
/// ## Redirects are not followed, because this client carries the token
///
/// Dio's default is `followRedirects: true` with `maxRedirects: 5`, and the IO
/// adapter hands both straight to `dart:io`'s `HttpClientRequest`, which replays
/// the request headers — `Authorization` included — at whatever host the
/// `Location` names. `ServerSessionInterceptor` attaches that header BEFORE the
/// redirect happens, so every authenticated call in the app was in scope.
///
/// This rule was already written down, and already applied, in
/// `server_probe.dart` — one request, made before the token is stored — and
/// missed on the client that carries the token for the rest of the app's life.
/// One client remembering is precisely what produced that, so
/// `test/data/redirect_policy_test.dart` now reads `lib/` and fails if ANY dio
/// instance is constructed without it.
///
/// The precondition is honest and narrow: over HTTPS a network attacker cannot
/// inject the 3xx, and `server_url.dart` refuses `http://` for anything but
/// loopback. The live shapes are a misconfigured reverse proxy and an owner
/// signed into a hostile host — the server URL is a free-text field, so that is
/// a supported flow, not an exotic one.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/interceptors.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/auth/identity_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_client.g.dart';

/// The app's dio instance, configured and authenticated.
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  // Rebuild every dependent repository/provider after sign-in or sign-out.
  ref.watch(serverSessionProvider);
  final dio = Dio(
    BaseOptions(
      // The build's default. A stored sign-in overrides it per request in
      // `ServerSessionInterceptor`, so the owner can point the app at their own
      // server without rebuilding it.
      baseUrl: Env.apiBaseUrl,
      connectTimeout: Env.requestTimeout,
      receiveTimeout: Env.requestTimeout,
      sendTimeout: Env.requestTimeout,
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
      // A 3xx would re-send the Authorization header to whatever host the
      // `Location` names. `maxRedirects: 0` beside it so the intent survives
      // someone flipping the flag back without reading the docstring.
      followRedirects: false,
      maxRedirects: 0,
      // Non-2xx is raised as a DioException so a failure cannot be mistaken for
      // an empty body — "no data" and "operation failed" must stay distinguishable
      // (Standards §1).
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.addAll([
    ServerSessionInterceptor(
      ref.watch(credentialsProvider),
      ref.watch(identityClientProvider),
    ),
    // A 401 ENDS the session rather than being replayed on every screen load
    // and every background sync. `ref.read`, not `watch`: watching the
    // repository here would rebuild this client — and its connection pool —
    // every time the flag it sets changes.
    //
    // ⛔ Invalidated ONCE per rejection — `noteRejected` owns that decision and
    // argues it. Announcing every 401 is a closed loop: invalidate → rebuild →
    // request → 401.
    SessionGuardInterceptor(() {
      if (ref.read(serverSessionRepositoryProvider).noteRejected()) {
        ref.invalidate(serverSessionProvider);
      }
    }),
    ApiLogInterceptor(logBodies: Env.logHttpBodies),
  ]);

  ref.onDispose(() => dio.close(force: true));
  return dio;
}
