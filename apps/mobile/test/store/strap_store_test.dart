/// The local tier's half of the contract: what a sync stores, and what survives.
///
/// Two of these tests are the ones that matter, and both are mutation-checked in
/// `test/mutations.sh`:
///
///   * **the daily counter reaches the store.** It is "since midnight", so it
///     cannot be re-read tomorrow — if it does not land on the day it was read,
///     that day's real step count is gone, exactly the way 142 production days
///     went before `device_daily_total` existed (#121).
///   * **day 61 is dropped.** The 60-day horizon is a hard product rule, and it
///     has to hold on every table rather than only on the one it was written for.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/strap_sync_result.dart';
import 'package:healthee/ble/models/workout.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/store/local_store.dart';

/// A sync result carrying whatever a test wants to store.
StrapSyncResult resultWith({
  List<StrapSample> samples = const [],
  List<SleepSession> sleep = const [],
  List<Workout> workouts = const [],
  DeviceDailyTotals? totals,
  int? battery,
  bool activityChannel = true,
  bool stressBackfillRan = false,
  bool napBackfillRan = false,
}) => StrapSyncResult(
  activityChannelPresent: activityChannel,
  samples: samples,
  sleepSessions: sleep,
  workouts: workouts,
  dailyTotals: totals,
  batteryPercent: battery,
  stressBackfillRan: stressBackfillRan,
  napBackfillRan: napBackfillRan,
  completedAt: DateTime(2026, 8, 4, 9, 30),
);

/// One night, staged, ending on [day].
SleepSession nightOn(DateTime start) => SleepSession(
  sessionStart: start,
  sleepStartMin: 0,
  sleepEndMin: 380,
  avgHr: 58,
  score: 86,
  stages: [
    SleepStageSeg(start, start.add(const Duration(hours: 2)), 5),
    SleepStageSeg(
      start.add(const Duration(hours: 2)),
      start.add(const Duration(hours: 6)),
      4,
    ),
  ],
  remMin: 90,
  lightMin: 200,
  deepMin: 90,
  wakeMin: 20,
);

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('the daily step counter', () {
    // #121, one layer up. The strap reports "since midnight", so a counter that
    // misses the store on the day it was read is not recoverable tomorrow.
    test('THE COUNTER REACHES THE STORE, and reads back whole', () async {
      final readAt = DateTime(2026, 8, 4, 9, 12);
      await store.strapWriter.saveSync(
        resultWith(
          totals: DeviceDailyTotals(
            steps: 9264,
            distanceM: 6710,
            calories: 412,
            readAt: readAt,
          ),
        ),
      );

      final day = await store.strapReader.day(isoDay(readAt));

      expect(day.steps, isA<Present<int>>());
      expect(day.steps.valueOrNull, 9264);
      expect(day.distanceKm.valueOrNull, closeTo(6.71, 1e-9));
      expect(day.deviceCalories.valueOrNull, 412);
      expect(day.stepsReadAt, readAt);
    });

    test('a strap that did not answer withholds — it never reports zero', () async {
      await store.strapWriter.saveSync(resultWith());

      final day = await store.strapReader.day('2026-08-04');

      expect(day.steps, isA<Withheld<int>>());
      expect(
        day.steps.valueOrNull,
        isNull,
        reason: '"the strap did not say" is not "the owner took no steps"',
      );
    });

    test('a later read replaces the same day rather than adding a row', () async {
      for (final (steps, hour) in [(4000, 9), (9264, 18)]) {
        await store.strapWriter.saveSync(
          resultWith(
            totals: DeviceDailyTotals(
              steps: steps,
              distanceM: steps,
              calories: 100,
              readAt: DateTime(2026, 8, 4, hour),
            ),
          ),
        );
      }

      final day = await store.strapReader.day('2026-08-04');
      expect(day.steps.valueOrNull, 9264);
      expect(await store.select(store.deviceTotals).get(), hasLength(1));
    });
  });

  group('samples, nights and sessions round-trip', () {
    test('the latest sample of a stream is what the day reports', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(DateTime(2026, 8, 4, 7), 'hrv', 41),
            StrapSample(DateTime(2026, 8, 4, 8), 'hrv', 47),
          ],
        ),
      );

      final day = await store.strapReader.day('2026-08-04');
      final hrv = day.metrics.firstWhere((m) => m.stream.metric == 'hrv');

      expect(hrv.reading.valueOrNull, 47);
      expect(hrv.measuredAt, DateTime(2026, 8, 4, 8));
      expect(hrv.sampleCount, 2);
    });

    test('a stream the strap never wrote is withheld, not absent', () async {
      await store.strapWriter.saveSync(resultWith());

      final day = await store.strapReader.day('2026-08-04');

      // Every stream keeps its row. A row that disappears on a bad day makes
      // the list shorter and the absence invisible.
      expect(day.metrics, hasLength(7));
      expect(day.metrics.every((m) => m.reading is Withheld<double>), isTrue);
    });

    test('a night that began yesterday is still last night', () async {
      await store.strapWriter.saveSync(
        resultWith(sleep: [nightOn(DateTime(2026, 8, 3, 23, 40))]),
      );

      final day = await store.strapReader.day('2026-08-04');

      expect(day.lastNight.valueOrNull, isNotNull);
      expect(day.lastNight.valueOrNull!.asleepMin, 380);
      expect(day.lastNight.valueOrNull!.stages, hasLength(2));
      expect(day.lastNight.valueOrNull!.stages.first.kind, 'deep');
    });

    test('re-storing an overlapping pull replaces rather than duplicates', () async {
      final night = nightOn(DateTime(2026, 8, 3, 23, 40));
      final workout = Workout(
        start: DateTime(2026, 8, 4, 6, 30),
        sportType: 6,
        durationSec: 1800,
        calories: 120,
        avgHr: 110,
        maxHr: 138,
        minHr: 92,
      );
      for (var i = 0; i < 2; i++) {
        await store.strapWriter.saveSync(
          resultWith(
            sleep: [night],
            workouts: [workout],
            samples: [StrapSample(DateTime(2026, 8, 4, 7), 'hr', 62)],
          ),
        );
      }

      expect(await store.select(store.sleepSessions).get(), hasLength(1));
      expect(await store.select(store.storedWorkouts).get(), hasLength(1));
      expect(await store.select(store.strapSamples).get(), hasLength(1));
    });
  });

  group('resuming', () {
    test('the watermark is the newest row on disk, per metric', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(DateTime(2026, 8, 4, 7), 'hr', 60),
            StrapSample(DateTime(2026, 8, 4, 9), 'hr', 66),
            StrapSample(DateTime(2026, 8, 4, 8), 'stress', 30),
          ],
        ),
      );

      final window = await store.strapWriter.resumeWindow();

      expect(window.lastSampleAt['hr'], DateTime(2026, 8, 4, 9));
      expect(window.lastSampleAt['stress'], DateTime(2026, 8, 4, 8));
      expect(
        window.lastSampleAt['hrv'],
        isNull,
        reason: 'a metric with no rows resumes from the 30-day floor',
      );
    });

    test('the one-shot flags are false until a complete pull sets them', () async {
      expect((await store.strapWriter.resumeWindow()).stressBackfillDone, isFalse);

      await store.strapWriter.markBackfillsRan(
        resultWith(stressBackfillRan: true),
      );

      final window = await store.strapWriter.resumeWindow();
      expect(window.stressBackfillDone, isTrue);
      expect(
        window.napBackfillDone,
        isFalse,
        reason: 'a pass that did not run must not be recorded as done',
      );
    });
  });

  group('partial is not complete', () {
    test('a partial attempt never moves "last complete sync"', () async {
      final complete = DateTime(2026, 8, 4, 8);
      await store.strapWriter.stampAttempt(
        at: complete,
        outcomeId: 'complete',
        complete: true,
      );
      await store.strapWriter.stampAttempt(
        at: DateTime(2026, 8, 4, 11),
        outcomeId: 'partial',
        complete: false,
      );

      final day = await store.strapReader.day('2026-08-04');

      expect(day.sync.lastCompleteSync, complete);
      expect(day.sync.lastAttempt, DateTime(2026, 8, 4, 11));
      expect(day.sync.lastAttemptIncomplete, isTrue);
    });

    test('a failed attempt is stamped too — silence would look like success', () async {
      await store.strapWriter.stampAttempt(
        at: DateTime(2026, 8, 4, 11),
        outcomeId: 'failed',
        complete: false,
      );

      final day = await store.strapReader.day('2026-08-04');
      expect(day.sync.lastCompleteSync, isNull);
      expect(day.sync.lastAttemptIncomplete, isTrue);
    });
  });

  group('the 60-day horizon holds on every table', () {
    const today = '2026-08-04';

    Future<void> seedAt(int daysAgo) {
      final at = DateTime(2026, 8, 4).subtract(Duration(days: daysAgo));
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

    test('DAY 61 IS GONE, and day 60 is kept — on all four tables', () async {
      await seedAt(localHorizonDays); // the boundary day, kept
      await seedAt(localHorizonDays + 1); // one past it, dropped
      // The horizon applies to a row the SERVER HAS. It never applied to an
      // unsent one — it only looked as though it did, which is the defect
      // `prune_safety_test.dart` exists for. Marking first is what keeps this
      // test about the horizon rather than about the guard.
      await store.pushReader.markPushed(
        await store.pushReader.pending(),
        DateTime(2026, 8, 4, 9, 30),
      );

      final report = await store.pruneBeyondHorizon(today);

      // One row per table for the day past the horizon.
      expect(report.sentMeasurements, 4);
      expect(report.unsentSamples, 0);
      for (final rows in [
        await store.select(store.strapSamples).get(),
        await store.select(store.sleepSessions).get(),
        await store.select(store.storedWorkouts).get(),
        await store.select(store.deviceTotals).get(),
      ]) {
        expect(rows, hasLength(1), reason: 'only the boundary day survives');
      }
      final survivor = (await store.select(store.strapSamples).get()).single;
      expect(survivor.day, horizonStart(today));
    });

    test('the sync bookkeeping is NOT pruned', () async {
      await store.strapWriter.markBackfillsRan(
        resultWith(napBackfillRan: true),
      );
      await store.pruneBeyondHorizon(today);

      expect(
        (await store.strapWriter.resumeWindow()).napBackfillDone,
        isTrue,
        reason: 'dropping the flag would re-run the wide pass forever',
      );
    });
  });
}
