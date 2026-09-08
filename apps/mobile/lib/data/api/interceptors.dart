/// The two interceptors on the app's dio client: the session and the logging.
///
/// Split from `api_client.dart` so the client file stays about wiring and these
/// stay about policy (Standards §1: one reason to change per file).
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/stored_server_session.dart';

/// Applies the owner's stored server session — the address AND the bearer token.
///
/// Both, in one interceptor, because they are one fact: the token was accepted
/// by *that* server and is meaningless at any other. Applying them from two
/// places would allow the combination this app must never build — one server's
/// credential sent to a different host.
///
/// The base URL only overrides `Env.apiBaseUrl` when a session is stored, so a
/// build's dart-define stays the default and a phone with no session behaves
/// exactly as before. `RequestOptions.uri` is a getter over `baseUrl + path`
/// (dio 5.11 `options.dart`), so setting it here is what the request goes to.
///
/// Reading per-request rather than caching at construction is deliberate:
/// sign-in, sign-out and moving to a different server all take effect on the
/// next call with no invalidation step. Secure-storage reads are a
/// platform-channel hop, not a network one, and they are off the render path.
///
/// **Nothing here is logged.** The token goes into a header and never into a log
/// line, a URL or a query — `test/signin/signin_secrecy_test.dart` drives the
/// app's real client through this interceptor and fails if it ever appears.
class ServerSessionInterceptor extends Interceptor {
  /// Reads the session from [credentials] on each request.
  ServerSessionInterceptor(this._credentials);

  final Credentials _credentials;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = options.extra.containsKey(CacheSession.requestKey)
        ? options.extra[CacheSession.requestKey] as StoredServerSession?
        : await _credentials.serverSession();
    if (session != null) {
      options.baseUrl = session.baseUrl;
      options.headers['Authorization'] = 'Bearer ${session.token}';
    }
    handler.next(options);
  }
}

/// Logs every request, response and failure through the one logging path.
///
/// Bodies are omitted unless `--dart-define=HELIO_LOG_HTTP=true`: a response here
/// is somebody's health data, and it should not end up in a device log because a
/// developer wanted a status code. The status, method, path and duration are
/// always logged, because those are what you need to answer "is it slow or is it
/// broken" and none of them are personal.
class ApiLogInterceptor extends Interceptor {
  /// [logBodies] should come from `Env.logHttpBodies`.
  ApiLogInterceptor({required this.logBodies});

  /// Whether to include request/response bodies in the log.
  final bool logBodies;

  static const String _startedAtKey = 'startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    AppLog.info('api', '→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final path = response.requestOptions.path;
    AppLog.info(
      'api',
      '← ${response.statusCode} $path ${_elapsed(response.requestOptions)}'
          '${logBodies ? ' ${response.data}' : ''}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Logged, then passed on — never swallowed (Standards §1). The repository
    // above turns this into a typed failure the UI can render with a retry.
    //
    // ⚠ The raw `DioException` goes to the logger, and it is safe against the
    // dio we pin: its `toString` emits `type`, `message` and `error` only, and
    // no factory message quotes the URI or the headers. `pubspec.yaml` pins a
    // CARET range, so a future minor could change that format without a change
    // here — which means **the guard is the test, not the pin**.
    // `test/signin/signin_secrecy_test.dart` drives this exact interceptor
    // stack with `AppLog.sink` capturing, including a 401 whose body echoes the
    // token, and fails if the credential appears anywhere in the transcript.
    // It is what has to survive a dependency bump; do not delete it as
    // redundant with this comment.
    AppLog.failure(
      'api',
      '${err.requestOptions.method} ${err.requestOptions.path} failed '
          '${_elapsed(err.requestOptions)}',
      err,
      err.stackTrace,
    );
    handler.next(err);
  }

  String _elapsed(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    if (startedAt is! DateTime) {
      return '';
    }
    return 'in ${DateTime.now().difference(startedAt).inMilliseconds}ms';
  }
}
