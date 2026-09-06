import 'package:dio/dio.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/stored_server_session.dart';

/// An operation's fixed account identity, shared by HTTP and its cache lookup.
class CacheSession {
  CacheSession._(this._credentials, this._session);

  final Credentials? _credentials;
  final StoredServerSession? _session;

  /// The interceptor must use the same snapshot that selected the cache.
  static const String requestKey = 'serverSessionSnapshot';

  /// Credentials are omitted only for repositories over an injected test client.
  static Future<CacheSession> capture(Credentials? credentials) async =>
      CacheSession._(credentials, await credentials?.serverSession());

  /// Signed-out reads can never select a signed-in cache.
  String get scope => _session?.cacheScope ?? '';
  String get origin => _session?.baseUrl ?? '';

  /// Bind this request to the captured session, including explicit sign-out.
  Options options({Duration? timeout}) => Options(
    receiveTimeout: timeout,
    sendTimeout: timeout,
    extra: {if (_credentials != null) requestKey: _session},
  );

  /// An old in-flight response/fallback cannot become the new account's UI.
  Future<void> ensureCurrent() async {
    if (_credentials == null) return;
    final current = await _credentials.serverSession();
    if ((current?.cacheScope ?? '') != scope) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
        message: 'Server session changed',
      );
    }
  }
}
