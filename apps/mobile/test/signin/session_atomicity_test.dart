import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/interceptors.dart';
import 'package:healthee/data/api/secret_store.dart';
import 'package:healthee/data/api/stored_server_session.dart';

class PausedStore implements SecretStore {
  final values = <String, String>{};
  Completer<void>? writeGate;
  bool fail = false;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    await writeGate?.future;
    if (fail) throw const FormatException('keystore write failed');
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async => values.remove(key);
}

void main() {
  test('a damaged atomic record never puts its token in the parse error', () {
    try {
      StoredServerSession.decode('{"token":"PRIVATE-TEST-TOKEN');
      fail('a damaged session must be rejected');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains('PRIVATE-TEST-TOKEN')));
    }
  });

  test('legacy half-sessions stay signed out', () async {
    for (final entry in [
      const MapEntry('helio_token', 'orphan-token'),
      const MapEntry('helio_base_url', 'https://test.example'),
    ]) {
      final store = PausedStore()..values[entry.key] = entry.value;
      expect(await Credentials(store).serverSession(), isNull);
    }
  });

  test('request during a session write sees the entire old session', () async {
    final store = PausedStore();
    final credentials = Credentials(store);
    await credentials.setServerSession(
      baseUrl: 'https://old.example',
      token: 'old-token',
      kind: StoredCredentialKind.shared,
    );
    store.writeGate = Completer<void>();
    final changing = credentials.setServerSession(
      baseUrl: 'https://new.example',
      token: 'new-token',
      kind: StoredCredentialKind.shared,
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://default.example'));
    addTearDown(dio.close);
    dio.interceptors.add(ServerSessionInterceptor(credentials, null));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.host, 'old.example');
          expect(options.headers['Authorization'], 'Bearer old-token');
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        },
      ),
    );
    await dio.get<Object?>('/api/today');
    store.writeGate!.complete();
    await changing;
    final session = await credentials.serverSession();
    expect(session!.baseUrl, 'https://new.example');
    expect(session.token, 'new-token');
  });

  test(
    'a failed write keeps the old pair, and sign-out cannot revive legacy keys',
    () async {
      final store = PausedStore();
      store.values.addAll({
        'helio_base_url': 'https://legacy.example',
        'helio_token': 'legacy',
      });
      final credentials = Credentials(store);
      expect((await credentials.serverSession())!.token, 'legacy');
      await credentials.setServerSession(
        baseUrl: 'https://old.example',
        token: 'old-token',
        kind: StoredCredentialKind.shared,
      );
      store.fail = true;
      await expectLater(
        credentials.setServerSession(
          baseUrl: 'https://new.example',
          token: 'new-token',
          kind: StoredCredentialKind.shared,
        ),
        throwsFormatException,
      );
      final session = await credentials.serverSession();
      expect(session!.baseUrl, 'https://old.example');
      expect(session.token, 'old-token');
      store.fail = false;
      await credentials.forgetServerSession();
      expect(await credentials.serverSession(), isNull);
    },
  );
}
