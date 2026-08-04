/// What actually goes on the wire, asserted against the server's own contract.
///
/// The test that matters most is `THE DAILY COUNTER REACHES THE PAYLOAD`. Its
/// twin in `test/store/strap_store_test.dart` proves the `0x0016` counter
/// reaches the local store; this one proves it survives the next hop. #121 cost
/// 142 production days of real step counts because that measurement had nowhere
/// durable to land, and a push that quietly dropped it would recreate the loss
/// with `device_daily_total` sitting right there, empty.
///
/// The expected key names are `ingest/models.py`'s — `HelioPayload` with
/// `samples` · `sleep` · `workouts` · `daily_totals`, and `DailyTotalIn` with
/// `day` · `steps` · `distance_m` · `calories`. They are spelled out here rather
/// than derived from the code under test, so a rename on either side fails.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/models/workout.dart';
import 'package:healthee/data/push/push_batch.dart';
import 'package:healthee/data/store/local_store.dart';

import '../store/strap_store_test.dart' show nightOn, resultWith;

const String _day = '2026-08-04';

/// Everything in [store] that has not been pushed, as the request body.
Future<Map<String, Object?>> _payloadOf(LocalStore store) async =>
    (await store.pushReader.pending()).toJson();

List<Map<String, Object?>> _list(Map<String, Object?> body, String key) =>
    (body[key]! as List).cast<Map<String, Object?>>();

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('the daily step counter (#121)', () {
    test('THE DAILY COUNTER REACHES THE PAYLOAD, whole', () async {
      await store.strapWriter.saveSync(
        resultWith(
          totals: DeviceDailyTotals(
            steps: 9264,
            distanceM: 6710,
            calories: 412,
            readAt: DateTime(2026, 8, 4, 9, 12),
          ),
        ),
      );

      final totals = _list(await _payloadOf(store), 'daily_totals');

      expect(totals, hasLength(1));
      expect(totals.single['day'], _day);
      expect(
        totals.single['steps'],
        9264,
        reason: 'the authoritative step total — the per-minute sum is frozen',
      );
      expect(totals.single['distance_m'], 6710);
      expect(totals.single['calories'], 412);
    });

    test('the counter is pending again after it grows', () async {
      Future<void> read(int steps, DateTime at) => store.strapWriter.saveSync(
        resultWith(
          totals: DeviceDailyTotals(
            steps: steps,
            distanceM: steps,
            calories: 1,
            readAt: at,
          ),
        ),
      );

      await read(4000, DateTime(2026, 8, 4, 9));
      final morning = await store.pushReader.pending();
      await store.pushReader.markPushed(morning, DateTime(2026, 8, 4, 9, 1));
      await read(11000, DateTime(2026, 8, 4, 21));

      final totals = _list(await _payloadOf(store), 'daily_totals');

      expect(
        totals.single['steps'],
        11000,
        reason: 'the counter grows all day under one key; the 09:00 figure '
            'having been sent says nothing about the 21:00 one',
      );
    });
  });

  group('metric names', () {
    test('every strap stream is translated to the server vocabulary', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(DateTime(2026, 8, 4, 7), 'hr', 61),
            StrapSample(DateTime(2026, 8, 4, 7, 1), 'steps', 42),
            StrapSample(DateTime(2026, 8, 4, 7, 2), 'temperature_c', 33.4),
            StrapSample(DateTime(2026, 8, 4, 7, 3), 'spo2_sleep', 96),
          ],
        ),
      );

      final samples = _list(await _payloadOf(store), 'samples');

      expect(samples.map((s) => s['metric']), <String>[
        'hr',
        'steps_per_minute',
        'skin_temp_c',
        // Two strap streams, one server metric: both are blood oxygen and the
        // server windows them itself.
        'spo2',
      ]);
    });

    test('every mapped name is one the server actually accepts', () {
      // `ALLOWED_METRICS` in apps/server/src/healthee/ingest/models.py, copied
      // here so a change on either side fails a test rather than becoming a
      // silent coerce-drop.
      const allowed = <String>{
        'hr',
        'hrv',
        'spo2',
        'skin_temp_c',
        'respiratory_rate',
        'stress',
        'steps_per_minute',
      };
      expect(kPushMetricNames.values.toSet(), allowed);
    });

    test('a stream the server derives for itself is NOT sent', () async {
      await store.strapWriter.saveSync(
        resultWith(
          samples: [
            StrapSample(DateTime(2026, 8, 4, 7), 'resting_hr', 62),
            StrapSample(DateTime(2026, 8, 4, 7, 1), 'max_hr', 171),
            StrapSample(DateTime(2026, 8, 4, 7, 2), 'sleep_session', 1),
            StrapSample(DateTime(2026, 8, 4, 7, 3), 'hr', 80),
          ],
        ),
      );

      final samples = _list(await _payloadOf(store), 'samples');

      expect(
        samples.map((s) => s['metric']),
        <String>['hr'],
        reason: 'resting HR is derived on the server; sending the strap\'s own '
            'would be a second definition of one number',
      );
    });
  });

  group('sleep and workouts', () {
    test('a night carries its hypnogram, and is bounded by it', () async {
      final start = DateTime(2026, 8, 3, 23, 40);
      await store.strapWriter.saveSync(resultWith(sleep: [nightOn(start)]));

      final nights = _list(await _payloadOf(store), 'sleep');

      expect(nights, hasLength(1));
      final night = nights.single;
      expect(night['kind'], 'main');
      expect(night['score'], 86);
      expect(night['deep_min'], 90);
      expect(night['light_min'], 200);
      expect(night['rem_min'], 90);
      expect(night['wake_min'], 20);
      // `SleepIn` materialises the per-minute stage stream from `stages`, so the
      // bounds must be the hypnogram's own rather than the summary minutes.
      final stages = (night['stages']! as List).cast<List<Object?>>();
      expect(stages, hasLength(2));
      expect(night['start_ts'], stages.first[0]);
      expect(night['end_ts'], stages.last[1]);
    });

    test('a night with no stages is not sent at all', () async {
      final start = DateTime(2026, 8, 3, 23, 40);
      await store.strapWriter.saveSync(
        resultWith(
          sleep: [
            SleepSession(
              sessionStart: start,
              sleepStartMin: 0,
              sleepEndMin: 300,
              avgHr: 0,
              score: 0,
              stages: const [],
              remMin: 0,
              lightMin: 0,
              deepMin: 0,
              wakeMin: 0,
              isNap: true,
            ),
          ],
        ),
      );

      expect(
        _list(await _payloadOf(store), 'sleep'),
        isEmpty,
        reason: 'a record with no timeline has no start or end we can state',
      );
    });

    test('a workout carries the device figures unaltered', () async {
      final start = DateTime(2026, 8, 4, 6, 30);
      await store.strapWriter.saveSync(
        resultWith(
          workouts: [
            Workout(
              start: start,
              sportType: 1,
              durationSec: 409,
              calories: 53,
              avgHr: 122,
              maxHr: 148,
              minHr: 96,
            ),
          ],
        ),
      );

      final workouts = _list(await _payloadOf(store), 'workouts');

      expect(workouts.single, <String, Object?>{
        'start_ts': start.millisecondsSinceEpoch,
        'sport': 1,
        'duration_s': 409,
        'calories': 53,
        'avg_hr': 122,
        'max_hr': 148,
        'min_hr': 96,
      });
    });
  });

  test('an empty store produces an empty batch, not an empty push', () async {
    final batch = await store.pushReader.pending();

    expect(batch.isEmpty, isTrue);
    expect(batch.rowCount, 0);
  });

  test('no profile is sent, because this app has none to send', () async {
    await store.strapWriter.saveSync(
      resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 7), 'hr', 61)]),
    );

    expect(
      (await _payloadOf(store)).containsKey('profile'),
      isFalse,
      reason: 'a half-built profile would move the owner\'s age, and age is an '
          'input to VO₂max and biological age',
    );
  });
}
