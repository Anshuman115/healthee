/// The prune cannot destroy a measurement the server has never seen — quietly.
///
/// The defect these tests pin: `pruneBefore` deleted from all five day-keyed
/// tables by `day` alone, so a row that had never been pushed died at 60 days
/// with no count, no date and no sentence anywhere. It needed a push queue stuck
/// for two months, which is why nobody would have found it by using the app.
///
/// Every claim here is about one of the three tiers in `horizon_prune.dart`:
///
///   * a cached payload goes at 60 days, because the server will send it again;
///   * a measurement the server acknowledged goes at 60 days, because the server
///     is its durable home;
///   * a measurement the server has NEVER seen survives the horizon — with no
///     second bound at all on the three event tables, and to one year on the
///     per-minute samples, where the drop is counted, dated and surfaced.
///
/// The `pushed_at_ms` guard is the whole fix and it only fires after 60 days, so
/// nobody would notice it broken. `test/mutations.sh` breaks it on purpose and
/// requires these tests to fail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/workout.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/health_lines.dart';

import 'strap_store_test.dart' show nightOn, resultWith;

const String _today = '2026-08-04';
final DateTime _todayAt = DateTime(2026, 8, 4);
final DateTime _now = DateTime(2026, 8, 4, 9, 30);

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  /// One sample, one night, one workout and one daily counter, [daysAgo] back.
  Future<void> seedAt(int daysAgo) {
    final at = _todayAt.subtract(Duration(days: daysAgo));
    return store.strapWriter.saveSync(
      resultWith(
        samples: [StrapSample(at, 'hr', 60)],
        sleep: [nightOn(at)],
        workouts: [
          Workout(
            start: at,
            sportType: 6,
            durationSec: 600,
            calories: 40,
            avgHr: 100,
            maxHr: 120,
            minHr: 80,
          ),
        ],
        totals: DeviceDailyTotals(
          steps: 100,
          distanceM: 80,
          calories: 5,
          readAt: at,
        ),
      ),
    );
  }

  /// Marks everything currently pending as accepted by the server.
  Future<void> markEverythingPushed() async {
    final batch = await store.pushReader.pending();
    await store.pushReader.markPushed(batch, _now);
  }

  Future<List<String>> sampleDays() async => [
    for (final row in await store.select(store.strapSamples).get()) row.day,
  ];

  group('a measurement the server has never seen', () {
    test('SURVIVES THE 60-DAY HORIZON on all four measurement tables', () async {
      // The defect, stated as its inverse. Before the fix all four of these
      // rows were deleted here, uncounted.
      await seedAt(localHorizonDays + 1);

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.sentMeasurements, 0);
      expect(report.unsentSamples, 0, reason: 'nothing was destroyed');
      expect(report.destroyedSomething, isFalse);
      for (final rows in [
        await store.select(store.strapSamples).get(),
        await store.select(store.sleepSessions).get(),
        await store.select(store.storedWorkouts).get(),
        await store.select(store.deviceTotals).get(),
      ]) {
        expect(rows, hasLength(1), reason: 'unsent rows are kept, not pruned');
      }
    });

    test('is still READABLE by pending(), so the push can still take it', () async {
      // Retention that hid a row from the drain would trade one silent loss for
      // another. The marker is untouched, so the row is pending by construction.
      await seedAt(localHorizonDays + 1);
      await store.pruneBeyondHorizon(_today, at: _now);

      final batch = await store.pushReader.pending();

      expect(batch.samples, hasLength(1));
      expect(batch.nights, hasLength(1));
      expect(batch.workouts, hasLength(1));
      expect(batch.totals, hasLength(1));
      expect(await store.pushReader.pendingCount(), 4);
    });

    test('and the horizon still applies to a CACHED PAYLOAD beside it', () async {
      // Tier 1 vs tier 2 in one pass: the same prune drops the derivable copy
      // and keeps the measurement.
      await seedAt(localHorizonDays + 1);
      await store.write(
        metric: 'today',
        day: isoDay(_todayAt.subtract(const Duration(days: 61))),
        payload: '{}',
        fetchedAt: _now,
      );

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.cachedPayloads, 1);
      expect(await store.select(store.cachedPayloads).get(), isEmpty);
      expect(await store.select(store.strapSamples).get(), hasLength(1));
    });
  });

  group('a measurement the server HAS acknowledged', () {
    test('IS PRUNED at 60 days, on all four tables', () async {
      await seedAt(localHorizonDays + 1);
      await markEverythingPushed();

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.sentMeasurements, 4, reason: 'one row per table');
      expect(report.unsentSamples, 0, reason: 'a pushed row is not a loss');
      for (final rows in [
        await store.select(store.strapSamples).get(),
        await store.select(store.sleepSessions).get(),
        await store.select(store.storedWorkouts).get(),
        await store.select(store.deviceTotals).get(),
      ]) {
        expect(rows, isEmpty);
      }
    });

    test('and the boundary day is kept, pushed or not', () async {
      await seedAt(localHorizonDays); // exactly at the cutoff
      await markEverythingPushed();

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.rows, 0);
      expect(await store.select(store.strapSamples).get(), hasLength(1));
    });
  });

  group('the three event tables have NO second bound', () {
    test('an unsent night, workout and counter outlive even a year', () async {
      // #121, one layer up: the daily counter is "since midnight" and cannot be
      // re-read tomorrow. These tables grow by events per day, not samples per
      // minute, so there is no storage argument for a bound and none is set.
      await seedAt(kUnsentSampleRetentionDays + 30);

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(await store.select(store.sleepSessions).get(), hasLength(1));
      expect(await store.select(store.storedWorkouts).get(), hasLength(1));
      expect(await store.select(store.deviceTotals).get(), hasLength(1));
      expect(
        report.unsentSamples,
        1,
        reason: 'only the per-minute sample hits the one-year bound',
      );
    });
  });

  group('the one-year bound, which is the only thing here that destroys data', () {
    test('THE BOUNDARY DAY IS KEPT and the day past it is not', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(
              _todayAt.subtract(const Duration(days: kUnsentSampleRetentionDays)),
              'hr',
              60,
            ),
            StrapSample(
              _todayAt.subtract(
                const Duration(days: kUnsentSampleRetentionDays + 1),
              ),
              'hr',
              61,
            ),
          ],
        ),
      );

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.unsentSamples, 1);
      expect(await sampleDays(), [unsentSampleFloor(_today)]);
    });

    test('IT COUNTS AND DATES WHAT IT DESTROYED, exactly', () async {
      // Three doomed rows on two days, plus one that is merely past the 60-day
      // horizon and must not be counted with them.
      final doomedDay = _todayAt.subtract(
        const Duration(days: kUnsentSampleRetentionDays + 1),
      );
      final olderDay = _todayAt.subtract(
        const Duration(days: kUnsentSampleRetentionDays + 40),
      );
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(doomedDay, 'hr', 60),
            StrapSample(doomedDay.add(const Duration(minutes: 1)), 'hr', 61),
            StrapSample(olderDay, 'hrv', 40),
            StrapSample(_todayAt.subtract(const Duration(days: 90)), 'hr', 62),
          ],
        ),
      );

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.unsentSamples, 3);
      expect(report.unsentThroughDay, isoDay(doomedDay));
      expect(report.destroyedSomething, isTrue);
      expect(
        report.rows,
        3,
        reason: 'the 90-day-old row is unsent, so it is kept, not pruned',
      );
      expect(await store.select(store.strapSamples).get(), hasLength(1));
    });

    test('and the loss is DURABLE, on the push surface, not just returned', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(
              _todayAt.subtract(
                const Duration(days: kUnsentSampleRetentionDays + 1),
              ),
              'hr',
              60,
            ),
          ],
        ),
      );
      await store.pruneBeyondHorizon(_today, at: _now);

      final stamp = await store.pushReader.lastAttempt();

      expect(stamp.loss, isNotNull);
      expect(stamp.loss!.rows, 1);
      expect(stamp.loss!.throughDay, isoDay(_todayAt.subtract(
        const Duration(days: kUnsentSampleRetentionDays + 1),
      )));
      expect(stamp.loss!.at, _now);
      expect(
        stamp.needsAttention,
        isTrue,
        reason: 'the queue is empty and the last push was clean — and the '
            'measurements are still gone',
      );
    });

    test('the count ACCUMULATES across prunes and never resets', () async {
      Future<void> seedSampleAt(DateTime at, String metric) =>
          store.strapWriter.saveSync(
            resultWith(samples: [StrapSample(at, metric, 60)]),
          );

      final first = _todayAt.subtract(
        const Duration(days: kUnsentSampleRetentionDays + 1),
      );
      await seedSampleAt(first, 'hr');
      await store.pruneBeyondHorizon(_today, at: _now);

      // A month later, a row that was inside the bound is now outside it.
      final later = _todayAt.add(const Duration(days: 31));
      await seedSampleAt(
        later.subtract(const Duration(days: kUnsentSampleRetentionDays + 1)),
        'hrv',
      );
      final second = await store.pruneBeyondHorizon(isoDay(later), at: _now);

      expect(second.unsentSamples, 1, reason: 'this pass destroyed one');
      final stamp = await store.pushReader.lastAttempt();
      expect(stamp.loss!.rows, 2, reason: 'but two have been destroyed here');
      expect(
        stamp.loss!.throughDay,
        isoDay(later.subtract(
          const Duration(days: kUnsentSampleRetentionDays + 1),
        )),
        reason: 'the NEWEST day lost, which the later prune supplied',
      );
    });

    test('IT SAYS SO OUT LOUD, with the count, the date and the remedy', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            for (var i = 0; i < 7; i++)
              StrapSample(
                _todayAt
                    .subtract(
                      const Duration(days: kUnsentSampleRetentionDays + 1),
                    )
                    .add(Duration(minutes: i)),
                'hr',
                60,
              ),
          ],
        ),
      );
      await store.pruneBeyondHorizon(_today, at: _now);

      final lines = dataHealthLines(
        now: _now,
        push: await store.pushReader.lastAttempt(),
      );

      expect(lines, isNotEmpty);
      final loss = lines.first;
      expect(loss.loud, isTrue, reason: 'never dressed as routine maintenance');
      expect(loss.text, contains('7 measurements'));
      expect(loss.text, contains('2025-08-03'));
      expect(loss.text, contains('without ever reaching a server'));
      expect(loss.text, contains('gone'));
      expect(
        loss.text,
        contains('Signing in'),
        reason: 'what the owner could have done',
      );
    });

    test('A SENT SAMPLE PAST THE BOUND IS PRUNED, and is not a loss', () async {
      // The guard cuts both ways. A row the server already holds is safe to
      // drop at any age, and counting it as destroyed would put a false loss
      // sentence on the card — the mirror image of the defect.
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(
              _todayAt.subtract(
                const Duration(days: kUnsentSampleRetentionDays + 1),
              ),
              'hr',
              60,
            ),
          ],
        ),
      );
      await markEverythingPushed();

      final report = await store.pruneBeyondHorizon(_today, at: _now);

      expect(report.sentMeasurements, 1);
      expect(report.unsentSamples, 0);
      expect(report.unsentThroughDay, isNull);
      expect(await sampleDays(), isEmpty);
      expect((await store.pushReader.lastAttempt()).loss, isNull);
    });
  });
}
