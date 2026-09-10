import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/interceptors.dart';
import 'package:healthee/data/api/stored_server_session.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/today_repository.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  late Credentials credentials;
  late LocalStore store;
  late Dio dio;

  setUp(() async {
    credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'owner-a',
      kind: StoredCredentialKind.shared,
    );
    store = LocalStore.memory();
    dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
    dio.interceptors.add(ServerSessionInterceptor(credentials, null));
  });
  tearDown(() async {
    dio.close();
    await store.close();
  });

  void offline() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
          );
        },
      ),
    );
  }

  Future<void> seed(String metric, Map<String, Object?> payload) async {
    final session = (await credentials.serverSession())!;
    await store.write(
      scope: session.cacheScope,
      metric: metric,
      day: '2026-09-06',
      payload: jsonEncode(payload),
      fetchedAt: DateTime(2026, 9, 6),
    );
  }

  test(
    'Today fallback remains available to its owner, never another session',
    () async {
      await seed('today', {'date': '2026-09-06', 'action': 'A private advice'});
      offline();
      final repository = TodayRepository(dio, store, credentials: credentials);
      expect((await repository.load()).snapshot.action, 'A private advice');
      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'owner-b',
        kind: StoredCredentialKind.shared,
      );
      await expectLater(repository.load(), throwsA(isA<DioException>()));
      await credentials.forgetServerSession();
      expect(await repository.cached(), isNull);
    },
  );

  test('Sleep fallback cannot cross accounts on the same server', () async {
    await seed('sleep', {});
    offline();
    final repository = SleepRepository(dio, store, credentials: credentials);
    await repository.page();
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'owner-b',
      kind: StoredCredentialKind.shared,
    );
    await expectLater(repository.page(), throwsA(isA<DioException>()));
  });

  test(
    'an in-flight old response neither returns nor populates the new cache',
    () async {
      final pending = Completer<RequestInterceptorHandler>();
      late RequestOptions sent;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = options;
            pending.complete(handler);
          },
        ),
      );
      final repository = TodayRepository(dio, store, credentials: credentials);
      final loading = repository.load();
      final assertion = expectLater(loading, throwsA(isA<DioException>()));
      final handler = await pending.future;
      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'owner-b',
        kind: StoredCredentialKind.shared,
      );
      handler.resolve(
        Response(
          requestOptions: sent,
          statusCode: 200,
          data: <String, Object?>{
            'date': '2026-09-06',
            'action': 'A private advice',
          },
        ),
      );
      await assertion;
      expect(await repository.cached(), isNull);
    },
  );
}
