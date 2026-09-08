import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/cached_account_read.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_snapshot.dart';
import 'package:healthee/data/store/local_store.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  late Credentials credentials;
  late LocalStore store;
  late Dio dio;
  late AccountApi api;
  setUp(() async {
    credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'a',
    );
    api = AccountApi(dio = Dio(), await CacheSession.capture(credentials));
    store = LocalStore.memory();
    await store.write(
      metric: 'feed',
      scope: api.sessionScope,
      day: '2026-09-06',
      payload: '{"count":3}',
      fetchedAt: DateTime.utc(2026, 9, 6),
    );
  });
  tearDown(() async {
    dio.close();
    await store.close();
  });
  Stream<ServerSnapshot<int>> read() => cachedAccountRead(
    api: api,
    store: store,
    path: '/api/feed',
    key: 'feed',
    parse: (data) => data['count']! as int,
  );

  test(
    'cached value renders first and carries offline refresh failure',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) => h.reject(
            DioException.connectionError(requestOptions: r, reason: 'offline'),
          ),
        ),
      );
      final values = await read().toList();
      expect(values.map((v) => v.data), [3, 3]);
      expect(values.first.stale, isTrue);
      expect(values.last.refreshError, isNotNull);
    },
  );
  test('refresh replaces the cached snapshot and its timestamp', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) => h.resolve(
          Response(requestOptions: r, data: <String, Object?>{'count': 7}),
        ),
      ),
    );
    final values = await read().toList();
    expect(values.map((v) => v.data), [3, 7]);
    expect(values.last.stale, isFalse);
  });
  test(
    'switching accounts while refresh waits refuses stale fallback',
    () async {
      final requested = Completer<void>();
      late RequestInterceptorHandler handler;
      late RequestOptions request;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            handler = h;
            request = r;
            requested.complete();
          },
        ),
      );
      final result = expectLater(read().toList(), throwsA(isA<DioException>()));
      await requested.future;
      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'b',
      );
      handler.reject(
        DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        ),
      );
      await result;
    },
  );
  test('a paywall refusal cannot keep showing a cached AI feed', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) => h.reject(
          DioException(
            requestOptions: r,
            response: Response(requestOptions: r, statusCode: 402),
            type: DioExceptionType.badResponse,
          ),
        ),
      ),
    );
    await expectLater(read().toList(), throwsA(isA<DioException>()));
    expect(await store.readLatest('feed', scope: api.sessionScope), isNull);
  });
}
