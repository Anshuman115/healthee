/// The golden parse test: the mobile models against the real wire contract.
///
/// It reads `packages/contracts/snapshots/today.json` **from the repository**,
/// not from a copy vendored into this package. That is the whole design of the
/// test. `packages/contracts/README.md` calls the snapshots the regression bed
/// that "guarantees the mobile app's expectations of the read API don't silently
/// break", and a copy would break exactly when it mattered — the server's
/// contract test would be updated, the copy would not, and both suites would go
/// green while the wire contract moved underneath the app.
///
/// So: one file, two suites. Regenerating the snapshot after a reviewed shape
/// change fails this test in the same commit, which is the intended alarm.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/models/today_snapshot.dart';
import 'package:healthee/data/models/vo2max.dart';

/// The snapshot, relative to `apps/mobile` — `flutter test`'s working directory.
const String _snapshotPath = '../../packages/contracts/snapshots/today.json';

Map<String, Object?> _loadSnapshot() {
  final file = File(_snapshotPath);
  if (!file.existsSync()) {
    fail(
      'Contract snapshot not found at $_snapshotPath (cwd ${Directory.current.path}). '
      'This test reads the repo copy on purpose — see the library docstring.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

void main() {
  late Map<String, Object?> json;
  late TodaySnapshot today;

  setUpAll(() {
    json = _loadSnapshot();
    today = TodaySnapshot.fromJson(json);
  });

  test('the committed snapshot parses at all', () {
    expect(today.date, '2026-07-31');
  });

  group('metric cards', () {
    test('every card in the payload becomes a typed card', () {
      expect(today.metrics, hasLength((json['metrics']! as List).length));
      expect(
        today.metrics.map((card) => card.metric),
        containsAll(<String>['rhr_daily', 'steps_total', 'weight_kg']),
      );
    });

    test('a normal card is Present, with its personal baseline', () {
      final rhr = today.metric('rhr_daily')!;
      expect(rhr.label, 'Resting HR');
      expect(rhr.unit, 'bpm');
      expect(rhr.reading, const Present<double>(55));
      expect(rhr.median30d, 55.0);
      expect(rhr.hasBaseline, isTrue);
      expect(rhr.anomalous, isFalse);
    });

    test('weight is Present but has NO baseline, and says so', () {
      // The documented exception (`docs/APP_DESIGN.md` §3.1: "Weight has no
      // baseline (z null) — show plainly"). It must not be mistaken for a
      // withheld value: there IS a number, there is just nothing to compare it to.
      final weight = today.metric('weight_kg')!;
      expect(weight.reading, const Present<double>(72.5));
      expect(weight.hasBaseline, isFalse);
      expect(weight.z, isNull);
    });
  });

  group('VO₂max', () {
    test('is Present, and names the instrument that read it', () {
      final reading = today.vo2max;
      expect(reading, isA<Present<Vo2max>>());

      final vo2max = (reading as Present<Vo2max>).value;
      expect(vo2max.estimate, 43.0);
      // [[hr_reserve_vo2max]] D4 — the instrument travels with the number.
      expect(vo2max.method, 'gps_graded');
      expect(vo2max.methodCaveat, isNotEmpty);
      // The ± band and WHICH kind of error it is.
      expect(vo2max.standardErrorMlKgMin, 2.95);
      expect(vo2max.standardErrorSource, contains('Carrier 2023'));
      expect(vo2max.medianForAge, 39.7);
      expect(vo2max.deltaFromMedian, 3.3);
      expect(vo2max.sessionCount, 1);
      expect(vo2max.researchNotes, contains('vo2max_fitness_mortality'));
    });

    test('the 90-day trend survives parsing in order', () {
      final vo2max = (today.vo2max as Present<Vo2max>).value;
      final raw = json['vo2max']! as Map<String, Object?>;
      expect(vo2max.trend90d, hasLength((raw['trend_90d']! as List).length));
      expect(vo2max.trend90d.first.date, '2026-07-02');
    });

    test('a withheld payload produces NO estimate to render', () {
      // The gate the server calls structural, checked on this side of the wire.
      // `read/vo2max.py` nulls `estimate` and `method` together and attaches the
      // block; the app must turn that into a refusal, not a blank card.
      final withheldJson = Map<String, Object?>.from(json)
        ..['vo2max'] = <String, Object?>{
          ...json['vo2max']! as Map<String, Object?>,
          'estimate': null,
          'method': null,
          'method_caveat': null,
          'as_of_date': null,
          'data_confidence': 'insufficient_data',
          'withheld': <String, Object?>{
            'reason': 'logged_weight_stale',
            'message':
                'The last weight you logged is more than two weeks old, so we '
                "can't call it your weight today — log a new one and this comes "
                'straight back.',
            'last_as_of_date': '2026-06-04',
            'age_days': 57,
            'last_estimate': 43.0,
          },
        };

      final reading = TodaySnapshot.fromJson(withheldJson).vo2max;

      expect(reading, isA<Withheld<Vo2max>>());
      expect(reading.valueOrNull, isNull);
      expect(reading.hasValue, isFalse);

      final disclosure = (reading as Withheld<Vo2max>).disclosure;
      expect(disclosure.reason, 'logged_weight_stale');
      // The remedy is the load-bearing half and must survive the trip.
      expect(disclosure.message, contains('log a new one'));
      expect(disclosure.asOfDate, '2026-06-04');
      expect(disclosure.ageDays, 57);
    });
  });

  group('biological age — the four-state payload', () {
    test('is Caveated: a real number, carrying what tilts it', () {
      final reading = today.biologicalAge;
      expect(reading, isA<Caveated<BiologicalAge>>());

      final caveated = reading as Caveated<BiologicalAge>;
      expect(caveated.value.biologicalAge, 34.3);
      expect(caveated.value.chronologicalAge, 36.0);
      expect(caveated.value.deltaYears, -1.7);
      expect(caveated.value.disclaimer, contains('not a clinical'));
    });

    test('the per-lever breakdown parses — the number is never shown alone', () {
      final value = (today.biologicalAge as Caveated<BiologicalAge>).value;
      expect(value.contributions, isNotEmpty);
      final fitness = value.contributions.firstWhere((c) => c.term == 'fitness');
      expect(fitness.value, 43.0);
      expect(fitness.target, 40.0);
      expect(fitness.method, 'gps_graded');
    });

    test('an exclusion beside a value narrows it — it does not suppress it', () {
      // The case a reasonable person gets wrong. `excluded` here means "sleep
      // regularity is not one of the levers behind this number", not "there is
      // no number". The value stays, and the exclusion travels with it.
      final raw = json['biological_age']! as Map<String, Object?>;
      final caveatCount = (raw['caveats']! as List).length;
      final excludedCount = (raw['excluded']! as List).length;
      expect(excludedCount, greaterThan(0), reason: 'the fixture must exercise this');

      final attached = (today.biologicalAge as Caveated<BiologicalAge>).caveats;
      expect(attached, hasLength(caveatCount + excludedCount));
      expect(
        attached.map((d) => d.reason),
        contains('sri_hazard_not_transportable'),
      );
    });
  });

  group('recovery', () {
    test('is Present, with the breakdown that licenses the composite', () {
      final reading = today.recovery;
      expect(reading, isA<Present<RecoveryScore>>());

      final recovery = (reading as Present<RecoveryScore>).value;
      expect(recovery.recovery, 72);
      expect(recovery.readiness, 36);
      expect(recovery.band, 'high');
      expect(recovery.noteId, 'recovery_readiness');
      // `feedback_no_composite_score`: a 0–100 score ships with its components.
      expect(recovery.factors.map((f) => f.name), containsAll(['hrv', 'rhr', 'rr', 'sleep']));
      final hrv = recovery.factors.firstWhere((f) => f.name == 'hrv');
      expect(hrv.subScore, 80);
      expect(hrv.weight, 0.3);
    });

    test('the guidance sentence is carried verbatim', () {
      // Deterministic text, and an active illness flag overrides it. The app
      // renders it as-is; re-wording it here would re-word a safety message.
      final recovery = (today.recovery as Present<RecoveryScore>).value;
      expect(recovery.guidance, json['recovery_score']!.asMap()['guidance']);
    });
  });

  group('data health', () {
    test('parses every feed and stays silent when all are fresh', () {
      final health = today.dataHealth!;
      expect(health.overall, 'ok');
      expect(health.items, hasLength(6));
      expect(health.degraded, isEmpty);
      // The trust card renders NOTHING when everything is current.
      expect(health.needsAttention, isFalse);
    });
  });

  test('the daily action is null in the fixture, and that is not a refusal', () {
    // `action: null` means the nightly job has not warmed it — "show nothing,
    // never a spinner". It is deliberately not a Reading, so it cannot render as
    // a withheld card and tell the owner something is wrong.
    expect(today.action, isNull);
  });
}

extension on Object {
  Map<String, Object?> asMap() => this as Map<String, Object?>;
}
