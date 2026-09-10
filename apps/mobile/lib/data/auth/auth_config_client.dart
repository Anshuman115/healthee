/// Asks a server which identity provider it expects. Carries no credential.
///
/// It cannot carry one: this is the call made in order to find out how to
/// authenticate, so there is nothing to present yet. That is also why the server
/// serves it unauthenticated (`api/routers/auth.py` argues it).
///
/// ## A bare client, for the same reason `ReleaseClient` uses one
///
/// Not the app's `apiClientProvider`: that has `ServerSessionInterceptor` on it
/// and would attach whatever session is stored. Here that would be the PREVIOUS
/// server's credential being sent to a NEW address the owner just typed — the one
/// direction a token must never travel. A bare [Dio] cannot do it.
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/server_url.dart';
import 'package:healthee/data/auth/auth_config.dart';

/// Where a server declares its identity provider.
const String kAuthConfigPath = '/api/auth-config';

/// How long the server is given. Short: this is one small JSON body, and it sits
/// in front of a sign-in somebody is waiting on.
const Duration kAuthConfigTimeout = Duration(seconds: 10);

/// Reads `GET /api/auth-config` from a server.
class AuthConfigClient {
  /// [dio] must be configured by [AuthConfigClient.dioFor].
  const AuthConfigClient(this._dio);

  /// A bare client: no base URL, no interceptors, and so no credential.
  static Dio dioFor({Duration timeout = kAuthConfigTimeout}) => Dio(
    BaseOptions(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      // A redirect would take an unauthenticated question somewhere unnamed, and
      // the answer decides where this phone sends a password next.
      followRedirects: false,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );

  final Dio _dio;

  /// What [url] says about its identity provider.
  ///
  /// Never throws: every outcome is one of the four results, because each needs a
  /// different sentence and an exception would collapse them into one.
  Future<AuthConfigResult> forServer(ServerUrl url) async {
    final Response<Object?> response;
    try {
      response = await _dio.getUri<Object?>(
        Uri.parse('${url.value}$kAuthConfigPath'),
      );
    } on DioException catch (error) {
      AppLog.info('signin', 'auth-config could not be reached (${error.type})');
      return const AuthConfigUnreachable();
    }
    final status = response.statusCode ?? 0;
    if (status == 404) {
      // The server predates the endpoint. Different remedy from "configured
      // nothing", which is why the server answers 200-with-nulls for that.
      AppLog.info('signin', 'this server has no auth-config endpoint');
      return const AuthConfigUnsupported();
    }
    if (status != 200) {
      AppLog.info('signin', 'auth-config answered $status');
      return const AuthConfigUnreachable();
    }
    final body = response.data;
    if (body is! Map<String, Object?>) {
      // A captive portal answering 200 with a login page. Not an answer about
      // this server, so it must not be read as one.
      AppLog.info('signin', 'auth-config returned a body this app cannot read');
      return const AuthConfigUnreachable();
    }
    final config = AuthConfig.fromJson(body);
    if (config == null) {
      AppLog.info('signin', 'this server names no identity provider');
      return const AuthConfigNone();
    }
    return AuthConfigFound(config);
  }

  /// Releases the connection pool.
  void close() => _dio.close();
}
