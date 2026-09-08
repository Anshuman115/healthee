import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/gps/gps_fix.dart';
import 'package:healthee/data/gps/gps_local_store.dart';
import 'package:healthee/data/gps/gps_repository.dart';
import 'package:healthee/data/store/local_store.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  test('lost response leaves route queued; retry reuses identity and waits for matching acknowledgement', () async {
    final database = LocalStore.memory();
    final dio = Dio();
    addTearDown(() async { dio.close(); await database.close(); });
    final credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(baseUrl: 'https://test.example', token: 'test');
    final local = GpsLocalStore(database, 'owner');
    final repository = GpsRepository(local: local,
      api: AccountApi(dio, await CacheSession.capture(credentials)));
    const id = '87069e7c-7b32-4862-9b56-594c7f41273e';
    final start = DateTime.utc(2026, 1, 1);
    await local.begin(id, start);
    for (var i = 0; i < 10; i++) {
      await local.append(id, GpsFix(at: start.add(Duration(seconds: i)),
        latitude: 12, longitude: 77, accuracyM: 8), 0);
    }
    await local.finish(id, start.add(const Duration(seconds: 10)));
    final requests = <Map<String, Object?>>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request.data! as Map<String, Object?>);
      if (requests.length == 1) {
        handler.reject(DioException.connectionError(requestOptions: request, reason: 'Response lost'));
      } else {
        handler.resolve(Response(requestOptions: request,
          data: <String, Object?>{'ok': true, 'track_id': id}));
      }
    }));
    await expectLater(repository.upload(id), throwsA(isA<DioException>()));
    expect((await local.recording(id)).status, 'ready');
    await repository.upload(id);
    expect(requests[0], requests[1]);
    expect(requests[1]['client_id'], id);
    expect((await local.recording(id)).status, 'uploaded');
    expect(await local.fixes(id), hasLength(10));
  });
}
