/// The two interceptors on the app's dio client: auth and logging.
///
/// Split from `api_client.dart` so the client file stays about wiring and these
/// stay about policy (Standards §1: one reason to change per file).
library;

import 'package:dio/dio.dart';
import 'package:healthee/core/logging.dart';
import 'package:healthee/data/api/credentials.dart';

/// Attaches the owner's bearer token to every outgoing request.
///
/// Reading the token per-request rather than caching it at construction is
/// deliberate: sign-in, sign-out and rotation all take effect on the next call
/// with no invalidation step. Secure-storage reads are a platform-channel hop,
/// not a network one, and they are off the render path.
class AuthInterceptor extends Interceptor {
  /// Reads the token from [credentials] on each request.
  AuthInterceptor(this._credentials);

  final Credentials _credentials;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _credentials.apiToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
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
  void onResponse(Response<Object?> response, ResponseInterceptorHandler handler) {
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
