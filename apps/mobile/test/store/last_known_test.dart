/// The walk backwards through the local tier for the last value we DID have.
///
/// The widget suites pin `lastKnownBiologicalAgeProvider` so they can ask what
/// the hero draws without a database in the way. This suite asks the other half:
/// given real cached payloads, does the repository find the right day — and does
/// it refuse to invent one.
///
/// The rules it holds, all of which are ways to get "stale-as-current" wrong:
///
///   * today's own row is the REFUSED one, so it must be walked past rather
///     than read;
///   * the answer is the newest day that actually carried a number, not the
///     newest row;
///   * a row that cannot be parsed is skipped and said out loud, never counted
///     as "no value";
///   * with nothing in the tier the answer is null — never a zero, never a
///     value borrowed from a neighbouring metric.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/today_repository.dart';

/// One day's `/api/today` body, carrying [age] as the biological age.
String _body(double? age) => jsonEncode(<String, Object?>{
  'biological_age': <String, Object?>{
    'biological_age': age,
    'chronological_age': 36,
  },
});

void main() {
  late LocalStore store;
  late TodayRepository repository;

  setUp(() {
    store = LocalStore.memory();
    repository = TodayRepository(Dio(), store);
  });
  tearDown(() async => store.close());

  Future<void> cache(String day, String payload) => store.write(
    metric: kTodayPayload,
    day: day,
    payload: payload,
    fetchedAt: DateTime.parse('${day}T09:00:00Z'),
  );

  test('AN EMPTY TIER ANSWERS NULL, NOT A NUMBER', () async {
    expect(await repository.lastKnownBiologicalAge(), isNull);
  });

  test("TODAY'S REFUSAL IS WALKED PAST, AND THE LAST REAL DAY IS FOUND", () async {
    await cache('2026-08-02', _body(34.3));
    await cache('2026-08-03', _body(null));
    // Today: the withheld payload that sent the hero looking in the first place.
    await cache('2026-08-04', _body(null));

    final held = await repository.lastKnownBiologicalAge();
    expect(held, isNotNull);
    expect(held!.value, 34.3);
    expect(
      held.day,
      '2026-08-02',
      reason: 'the newest day that carried a number, not the newest row',
    );
  });

  test('THE NEWEST VALUE WINS, NOT THE FIRST ONE FOUND', () async {
    await cache('2026-07-01', _body(31.0));
    await cache('2026-07-20', _body(34.3));
    await cache('2026-08-04', _body(null));

    expect((await repository.lastKnownBiologicalAge())!.day, '2026-07-20');
  });

  test('A ROW WE CANNOT READ IS SKIPPED, NOT COUNTED', () async {
    await cache('2026-08-01', _body(33.1));
    await cache('2026-08-03', 'not json at all {');

    final held = await repository.lastKnownBiologicalAge();
    expect(held!.value, 33.1);
    expect(held.day, '2026-08-01');
  });

  test('A BLOCK WITH NO BIOLOGICAL AGE IS NOT A BIOLOGICAL AGE', () async {
    await cache('2026-08-03', jsonEncode(<String, Object?>{'vo2max': <String, Object?>{'estimate': 43.0}}));

    expect(
      await repository.lastKnownBiologicalAge(),
      isNull,
      reason: 'never carry a value forward from another metric',
    );
  });

  test('A DIFFERENT SIGN-IN’S CACHE IS NOT THIS OWNER’S HISTORY', () async {
    await store.write(
      scope: 'someone-else',
      metric: kTodayPayload,
      day: '2026-08-03',
      payload: _body(29.0),
      fetchedAt: DateTime.utc(2026, 8, 3),
    );

    expect(await repository.lastKnownBiologicalAge(), isNull);
  });
}
