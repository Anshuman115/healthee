/// The canonical read of each vital, and the aggregate it reads from.
///
/// Both `StrapData` and `Vitals` shipped in the legacy app with no tests at
/// all. They are ported verbatim, so these are **regression pins**: they fix
/// today's definitions in place so a later edit has to be deliberate.
///
/// The one that matters most is that HRV, SpO₂, skin temperature and
/// respiratory rate are means over the LAST SLEEP WINDOW, never the latest
/// reading. A daytime HRV sample is not a resting HRV, and `latest()` on those
/// metrics would quietly publish one as the other.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/sleep_session.dart';
import 'package:healthee/ble/models/strap_data.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/ble/vitals.dart';

final DateTime _night = DateTime(2026, 8, 3, 23);

SleepSession _session({required DateTime start, required DateTime end}) =>
    SleepSession(
      sessionStart: start,
      sleepStartMin: 0,
      sleepEndMin: 0,
      avgHr: 55,
      score: 80,
      stages: [SleepStageSeg(start, end, 4)],
      remMin: 60,
      lightMin: 120,
      deepMin: 40,
      wakeMin: 10,
    );

StrapData _dataWithNight() {
  final data = StrapData()
    ..sleep = [_session(start: _night, end: _night.add(const Duration(hours: 7)))];
  return data;
}

void main() {
  group('StrapData files and summarises samples', () {
    test('ingest groups by metric and latest reads the last one', () {
      final data = StrapData()
        ..ingest([
          StrapSample(_night, 'hr', 60),
          StrapSample(_night.add(const Duration(minutes: 1)), 'hr', 64),
          StrapSample(_night, 'stress', 30),
        ]);

      expect(data.count('hr'), 2);
      expect(data.count('stress'), 1);
      expect(data.latest('hr'), 64);
      expect(data.latest('spo2'), isNull, reason: 'absent, not zero');
      expect(data.isEmpty, isFalse);
    });

    test('median and delta over an even and an odd count', () {
      final odd = StrapData()
        ..ingest([
          for (final v in [50.0, 70.0, 60.0])
            StrapSample(_night, 'hr', v),
        ]);
      expect(odd.median('hr'), 60);
      expect(odd.delta('hr'), 0, reason: 'latest 60 minus median 60');

      final even = StrapData()
        ..ingest([
          for (final v in [50.0, 60.0, 70.0, 80.0])
            StrapSample(_night, 'hr', v),
        ]);
      expect(even.median('hr'), 65);
      expect(even.delta('hr'), 15);
    });

    test('daily totals sum per local day; daily-last takes the last', () {
      final day1 = DateTime(2026, 8, 1, 9);
      final day2 = DateTime(2026, 8, 2, 9);
      final data = StrapData()
        ..ingest([
          StrapSample(day1, 'steps', 100),
          StrapSample(day1.add(const Duration(hours: 2)), 'steps', 250),
          StrapSample(day2, 'steps', 400),
          StrapSample(day1, 'resting_hr', 58),
          StrapSample(day1.add(const Duration(hours: 5)), 'resting_hr', 55),
        ]);

      expect(data.dailyTotal('steps').map((d) => d.total).toList(), [350, 400]);
      expect(data.dailyLast('resting_hr').single.value, 55);
    });

    test('step buckets are 15 minutes wide and cover the most recent day', () {
      final start = DateTime(2026, 8, 3);
      final data = StrapData()
        ..ingest([
          StrapSample(start.add(const Duration(minutes: 5)), 'steps', 30),
          StrapSample(start.add(const Duration(minutes: 10)), 'steps', 20),
          StrapSample(start.add(const Duration(minutes: 20)), 'steps', 40),
        ]);

      final buckets = data.stepBuckets();
      expect(buckets.map((b) => b.bucket).toList(), [0, 1]);
      expect(buckets.first.steps, 50);
      expect(buckets.last.steps, 40);
    });

    test('hourly buckets carry min, max and mean — bucketed by UTC hour', () {
      // REPORTED, NOT FIXED: `hourly` buckets on `epochMs ~/ 3600000`, which is
      // a UTC hour boundary. In a zone offset by a whole number of hours that is
      // also the local hour; in a half-hour zone (IST, for one) a local hour is
      // split across two buckets. Ported verbatim, so the fixture is built on
      // the epoch boundary rather than a local one and the wart is written down
      // instead of papered over.
      final hourStart = DateTime.fromMillisecondsSinceEpoch(
        (DateTime(2026, 8, 3, 7).millisecondsSinceEpoch ~/ 3600000) * 3600000,
      );
      final data = StrapData()
        ..ingest([
          StrapSample(hourStart, 'hr', 60),
          StrapSample(hourStart.add(const Duration(minutes: 30)), 'hr', 80),
        ]);

      final buckets = data.hourly('hr');
      expect(buckets, hasLength(1));
      expect(buckets.single.avg, 70);
      expect(buckets.single.min, 60);
      expect(buckets.single.max, 80);
      expect(buckets.single.hour, hourStart);
    });

    test('points downsample rather than dropping the tail', () {
      final data = StrapData()
        ..ingest([
          for (var i = 0; i < 1000; i++)
            StrapSample(_night.add(Duration(minutes: i)), 'hr', 60),
        ]);

      expect(data.points('hr', max: 100).length, lessThanOrEqualTo(100));
      expect(data.points('missing'), isEmpty);
    });

    test('lastNight is the newest session regardless of insertion order', () {
      final older = _session(
        start: _night.subtract(const Duration(days: 1)),
        end: _night,
      );
      final newer = _session(
        start: _night,
        end: _night.add(const Duration(hours: 6)),
      );
      final data = StrapData()..sleep = [newer, older];

      expect(data.lastNight!.sessionStart, newer.sessionStart);
      expect(data.sleepByNight.first.sessionStart, newer.sessionStart);
    });

    test('clear empties the series but the aggregate stays usable', () {
      final data = _dataWithNight()..ingest([StrapSample(_night, 'hr', 60)]);
      data.clear();
      expect(data.isEmpty, isTrue);
      expect(data.latest('hr'), isNull);
    });
  });

  group('Vitals — one definition per metric', () {
    test('overnight metrics are the sleep-window MEAN, not the latest', () {
      final data = _dataWithNight()
        ..ingest([
          StrapSample(_night.add(const Duration(hours: 1)), 'hrv', 40),
          StrapSample(_night.add(const Duration(hours: 3)), 'hrv', 60),
          // A daytime reading, well outside the window — noisy and
          // unrepresentative, and it must not move the number.
          StrapSample(_night.add(const Duration(hours: 20)), 'hrv', 5),
        ]);

      expect(Vitals(data).hrv, 50);
      expect(data.latest('hrv'), 5, reason: 'which is exactly why not latest()');
    });

    test('SpO₂ prefers the device sleep stream over the spot one', () {
      final data = _dataWithNight()
        ..ingest([
          StrapSample(_night.add(const Duration(hours: 1)), 'spo2', 90),
          StrapSample(_night.add(const Duration(hours: 2)), 'spo2_sleep', 96),
          StrapSample(_night.add(const Duration(hours: 3)), 'spo2_sleep', 94),
        ]);

      expect(Vitals(data).spo2, 95);
      expect(Vitals(data).spo2Low, 94);
    });

    test('SpO₂ falls back to the spot stream when there is no sleep stream', () {
      final data = _dataWithNight()
        ..ingest([
          StrapSample(_night.add(const Duration(hours: 1)), 'spo2', 97),
          StrapSample(_night.add(const Duration(hours: 2)), 'spo2', 93),
        ]);

      expect(Vitals(data).spo2, 95);
      expect(Vitals(data).spo2Low, 93);
    });

    test('instantaneous metrics ARE the latest reading', () {
      final data = _dataWithNight()
        ..ingest([
          StrapSample(_night, 'hr', 60),
          StrapSample(_night.add(const Duration(hours: 20)), 'hr', 88),
          StrapSample(_night.add(const Duration(hours: 20)), 'resting_hr', 54),
          StrapSample(_night.add(const Duration(hours: 20)), 'max_hr', 171),
          StrapSample(_night.add(const Duration(hours: 20)), 'stress', 42),
        ]);

      final vitals = Vitals(data);
      expect(vitals.heartRate, 88);
      expect(vitals.restingHr, 54);
      expect(vitals.maxHr, 171);
      expect(vitals.stress, 42);
      expect(
        vitals.sleepAvgHr,
        60,
        reason: 'the sleep average excludes the daytime reading',
      );
    });

    test('with no night, every overnight metric is null rather than a guess', () {
      final data = StrapData()
        ..ingest([
          StrapSample(_night, 'hrv', 40),
          StrapSample(_night, 'temperature_c', 34.2),
          StrapSample(_night, 'respiratory_rate', 14),
          StrapSample(_night, 'spo2_sleep', 96),
        ]);

      final vitals = Vitals(data);
      expect(vitals.hrv, isNull);
      expect(vitals.skinTemp, isNull);
      expect(vitals.respiratoryRate, isNull);
      expect(vitals.spo2, isNull);
      expect(vitals.spo2Low, isNull);
    });

    test('a night with no samples in its window is null, not zero', () {
      final data = _dataWithNight();
      expect(Vitals(data).hrv, isNull);
      expect(Vitals(data).spo2Low, isNull);
    });

    test('nightly means are one point per night, chronological', () {
      final data = StrapData()
        ..sleep = [
          _session(
            start: _night.subtract(const Duration(days: 1)),
            end: _night.subtract(const Duration(days: 1)).add(const Duration(hours: 6)),
          ),
          _session(start: _night, end: _night.add(const Duration(hours: 6))),
        ]
        ..ingest([
          StrapSample(
            _night.subtract(const Duration(days: 1)).add(const Duration(hours: 1)),
            'hrv',
            30,
          ),
          StrapSample(_night.add(const Duration(hours: 1)), 'hrv', 50),
        ]);

      final nightly = data.nightlyMean('hrv');
      expect(nightly.map((n) => n.value).toList(), [30, 50]);
    });
  });
}
