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
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/interceptors.dart';
import 'package:healthee/data/api/server_session.dart';
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
      // Non-2xx is raised as a DioException so a failure cannot be mistaken for
      // an empty body — "no data" and "operation failed" must stay distinguishable
      // (Standards §1).
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  dio.interceptors.addAll([
    ServerSessionInterceptor(ref.watch(credentialsProvider)),
    ApiLogInterceptor(logBodies: Env.logHttpBodies),
  ]);

  ref.onDispose(() => dio.close(force: true));
  return dio;
}
