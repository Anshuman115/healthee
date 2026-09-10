import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/account_api.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/problem_message.dart';
import 'package:healthee/data/api/stored_server_session.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  late Dio dio;
  late Credentials credentials;
  late CommitmentRepository repository;
  final requests = <RequestOptions>[];
  setUp(() async {
    requests.clear();
    credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'a',
      kind: StoredCredentialKind.shared,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              data: <String, Object?>{'ok': true},
            ),
          );
        },
      ),
    );
    repository = CommitmentRepository(
      AccountApi(dio, await CacheSession.capture(credentials)),
    );
  });
  tearDown(() => dio.close());
  test('recalibration asks server without dictating a target', () async {
    await repository.challengeAction(42, 'adapt');
    expect(requests.single.path, '/api/challenges/42/adapt');
    expect(requests.single.data, isNull);
    expect(requests.single.queryParameters, isEmpty);
  });
  test(
    'challenge and program lifecycle writes use acknowledged endpoints',
    () async {
      await repository.challengeAction(42, 'adopt');
      await repository.challengeAction(42, 'abandon');
      await repository.programAction(7, 'adopt');
      await repository.programAction(7, 'abandon');
      expect(requests.map((r) => r.method), everyElement('POST'));
      expect(requests.map((r) => r.path), [
        '/api/challenges/42/adopt',
        '/api/challenges/42/abandon',
        '/api/programs/7/adopt',
        '/api/programs/7/abandon',
      ]);
    },
  );
  test(
    'stale generation action cannot spend another account allowance',
    () async {
      await credentials.setServerSession(
        baseUrl: 'https://test.example',
        token: 'b',
        kind: StoredCredentialKind.shared,
      );
      await expectLater(
        repository.generateChallenges(),
        throwsA(isA<DioException>()),
      );
      expect(requests, isEmpty);
    },
  );
  test('refusal reason and access denial are distinguishable', () {
    final options = RequestOptions();
    final conflict = DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: 409,
        data: <String, Object?>{
          'detail': {'error': 'Recovery is low'},
        },
      ),
    );
    expect(apiProblem(conflict), 'Recovery is low');
    expect(
      apiProblem(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 402),
        ),
      ),
      contains('access'),
    );
  });
}
