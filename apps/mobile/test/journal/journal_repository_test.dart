import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/api/cache_session.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/stored_server_session.dart';
import 'package:healthee/data/journal/journal_repository.dart';
import 'package:healthee/data/journal/log_draft.dart';
import 'package:healthee/data/journal/log_kind.dart';

import '../pairing/_pairing_fakes.dart';

void main() {
  late Dio dio;
  late Credentials credentials;
  late JournalRepository repository;
  final requests = <RequestOptions>[];
  Map<String, Object?> result = {'ok': true};

  setUp(() async {
    requests.clear();
    result = {'ok': true};
    dio = Dio(BaseOptions(baseUrl: 'https://test.example'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(requestOptions: options, data: result, statusCode: 200),
          );
        },
      ),
    );
    credentials = Credentials(FakeSecretStore());
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'a',
      kind: StoredCredentialKind.shared,
    );
    repository = JournalRepository(
      dio,
      await CacheSession.capture(credentials),
    );
  });
  tearDown(() => dio.close());

  test('duration preserves the selected end instant and unit', () async {
    final at = DateTime.utc(2026, 1, 2, 8);
    await repository.save(LogDraft(kind: LogKind.exercise, at: at, amount: 30));
    expect(requests.single.data, {
      'type': 'exercise',
      'at': at.millisecondsSinceEpoch,
      'minutes': 30,
      'unit': 'min',
    });
  });

  test('server business-rule refusal cannot report success', () async {
    result = {'ok': false, 'error': 'a fast is already open'};
    await expectLater(repository.fasting(end: false), throwsFormatException);
  });

  test('discarded short fast is disclosed', () async {
    result = {'ok': true, 'discarded': 'Too short'};
    expect(await repository.fasting(end: true), 'Too short');
  });

  test('a stale editor cannot write to the replacement account', () async {
    await credentials.setServerSession(
      baseUrl: 'https://test.example',
      token: 'b',
      kind: StoredCredentialKind.shared,
    );
    await expectLater(
      repository.fasting(end: false),
      throwsA(isA<DioException>()),
    );
    expect(requests, isEmpty);
  });

  test('reads parse nullable observations and fasting state', () async {
    result = {
      'entries': [
        {
          'type': 'mood',
          'ts': 1000,
          'name': 'Tired',
          'amount': null,
          'unit': null,
          'notes': 'Long day',
        },
      ],
      'fast': {
        'open': true,
        'current': {'duration_min': 42},
      },
    };
    final feed = await repository.recent();
    expect(feed.entries.single.name, 'Tired');
    expect(
      feed.entries.single.at,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
    expect(feed.fastOpen, isTrue);
    expect(feed.fastMinutes, 42);
  });

  test('invalid amounts and future observations never reach HTTP', () async {
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        repository.save(
          LogDraft(kind: LogKind.weight, at: DateTime(2026), amount: amount),
        ),
        throwsFormatException,
      );
    }
    await expectLater(
      repository.save(
        LogDraft(
          kind: LogKind.habit,
          at: DateTime.now().add(const Duration(days: 1)),
          name: 'Walk',
        ),
      ),
      throwsFormatException,
    );
    expect(requests, isEmpty);
  });

  test('duration requires whole minutes and named entries require text', () {
    final at = DateTime(2026);
    expect(
      LogDraft(kind: LogKind.meditation, at: at, amount: 1.5).validate(at),
      isNotNull,
    );
    for (final kind in [LogKind.habit, LogKind.mood, LogKind.symptom]) {
      expect(LogDraft(kind: kind, at: at, name: ' ').validate(at), isNotNull);
      expect(
        LogDraft(kind: kind, at: at, name: 'Observation').validate(at),
        isNull,
      );
    }
  });
}
