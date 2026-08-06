import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/push/push_stamp.dart';
import 'package:healthee/data/store/local_store.dart';

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  test('a written payload reads back whole', () async {
    await store.write(
      metric: 'today',
      day: '2026-07-31',
      payload: '{"date":"2026-07-31"}',
      fetchedAt: DateTime.utc(2026, 7, 31, 12),
    );

    final row = await store.read('today', '2026-07-31');

    expect(row, isNotNull);
    expect(row!.payload, '{"date":"2026-07-31"}');
  });

  test('a day never written reads as null, not as an empty payload', () async {
    // "No data" and "operation failed" are different states and must stay
    // distinguishable by the caller (Standards §1). An empty string would be a
    // payload; null is an absence.
    expect(await store.read('today', '2026-07-30'), isNull);
  });

  test('writing the same (day, metric) replaces rather than duplicates', () async {
    for (final body in ['{"v":1}', '{"v":2}']) {
      await store.write(
        metric: 'today',
        day: '2026-07-31',
        payload: body,
        fetchedAt: DateTime.utc(2026, 7, 31, 12),
      );
    }

    final row = await store.read('today', '2026-07-31');
    expect(row!.payload, '{"v":2}');
    expect(await store.select(store.cachedPayloads).get(), hasLength(1));
  });

  test('the day key survives the round trip unchanged, in any timezone', () async {
    // The regression this table's TEXT key exists to prevent: a drift
    // `dateTime()` column stores a Unix timestamp and returns it in the DEVICE's
    // zone, so the same write reads back as a different calendar date depending
    // on where the phone is. CI runs this suite under two timezones; a date that
    // is really a date cannot notice either of them.
    await store.write(
      metric: 'today',
      day: '2026-06-01',
      payload: '{}',
      fetchedAt: DateTime.utc(2026, 6, 1),
    );

    final row = await store.read('today', '2026-06-01');
    expect(row!.day, '2026-06-01');
  });

  test('fetchedAt comes back as the same UTC instant it went in as', () async {
    final at = DateTime.utc(2026, 7, 31, 18, 45);
    await store.write(metric: 'today', day: '2026-07-31', payload: '{}', fetchedAt: at);

    final row = await store.read('today', '2026-07-31');
    expect(row!.fetchedAt.toUtc(), at);
  });

  group('the 60-day horizon', () {
    const today = '2026-07-31';

    Future<void> seed(int daysAgo) {
      final day = DateTime.utc(2026, 7, 31).subtract(Duration(days: daysAgo));
      return store.write(
        metric: 'today',
        day: isoDay(day),
        payload: '{}',
        fetchedAt: DateTime.utc(2026, 7, 31),
      );
    }

    test('horizonStart is exactly 60 days back', () {
      expect(horizonStart(today), '2026-06-01');
      expect(localHorizonDays, 60);
    });

    test('keeps the boundary day and drops the one past it', () async {
      await seed(localHorizonDays); // exactly at the cutoff — kept
      await seed(localHorizonDays + 1); // one day beyond — dropped

      final report = await store.pruneBeyondHorizon(today);

      expect(
        report.cachedPayloads,
        1,
        reason: 'only the row past the horizon may be dropped',
      );
      final survivors = await store.select(store.cachedPayloads).get();
      expect(survivors, hasLength(1));
      expect(survivors.single.day, '2026-06-01');
    });

    test('reports what it removed rather than pruning silently', () async {
      await seed(200);
      await seed(300);
      final report = await store.pruneBeyondHorizon(today);
      expect(report.cachedPayloads, 2);
      expect(report.rows, 2);
    });

    test('A CACHED PAYLOAD IS NOT A MEASUREMENT, so it goes by date alone', () async {
      // Tier 1. A payload older than the UNSENT bound is still only a cached
      // copy of something the server will send again, so it is dropped and it
      // is never counted as something destroyed.
      await seed(kUnsentSampleRetentionDays + 1);

      final report = await store.pruneBeyondHorizon(today);

      expect(report.cachedPayloads, 1);
      expect(report.unsentSamples, 0);
      expect(report.destroyedSomething, isFalse);
      expect(await store.pushReader.lastAttempt(), isA<PushStamp>()
          .having((s) => s.loss, 'loss', isNull));
    });
  });
}
