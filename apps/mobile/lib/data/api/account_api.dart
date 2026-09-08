import 'package:dio/dio.dart';
import 'package:healthee/core/env.dart';
import 'package:healthee/data/api/api_client.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_api.g.dart';

/// One fixed account for an editor's lifetime, including every write and reply.
class AccountApi {
  const AccountApi(this._dio, this._session);
  final Dio _dio;
  final CacheSession _session;
  String get sessionScope => _session.scope;
  String get origin => _session.origin;
  Future<void> ensureCurrent() => _session.ensureCurrent();

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, Object?>? query,
  }) => request(
    path,
    query: query,
    timeout: path.contains('insight') || path == '/api/notable'
        ? Env.pushTimeout
        : null,
  );

  Future<Map<String, Object?>> request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    Duration? timeout,
    Map<String, Object?>? query,
  }) async {
    await _session.ensureCurrent();
    final response = await _dio.request<Map<String, Object?>>(
      path,
      data: body,
      queryParameters: query,
      options: _session.options().copyWith(
        method: method,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );
    await _session.ensureCurrent();
    if (response.data == null) {
      throw const FormatException('Empty server response');
    }
    return response.data!;
  }
}

@riverpod
Future<AccountApi> accountApi(Ref ref) async {
  final dio = ref.watch(apiClientProvider);
  final session = await CacheSession.capture(ref.watch(credentialsProvider));
  return AccountApi(dio, session);
}
