/// Reads one day of stored strap measurements back out as a typed [DeviceDay].
///
/// The mirror of `strap_writer.dart`, and the only path from SQLite to the
/// screen. Everything above it sees [DeviceDay]; nothing above it sees a row, a
/// column name, or a nullable double (Standards §3 — typed models at the data
/// boundary).
///
/// ## Where the honesty states are decided
///
/// Here, once, for every field — the same argument `data/honesty/envelope.dart`
/// makes for the server payload. A screen never asks "is this null"; it switches
/// on a [Reading]. And the distinction the store is uniquely able to draw is the
/// one this file exists to keep: **a row that is absent because the sensor wrote
/// nothing** is `notMeasured`, and it is a different refusal from one the
/// server sends.
/// Both are withholds; they carry different reasons and different remedies, and
/// a caller cannot accidentally produce the wrong one because neither is
/// constructed at the call site.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_metric.dart';
import 'package:healthee/data/device/device_night.dart';
import 'package:healthee/data/device/device_workout.dart';
import 'package:healthee/data/honesty/device_absence.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/strap_writer.dart';
import 'package:healthee/data/store/tables.dart';

part 'strap_reader.g.dart';

/// The stream the day chart is drawn from, and the one Today headlines.
const String kHeartRateMetric = 'hr';

/// Builds [DeviceDay] out of the local tier.
@DriftAccessor(
  tables: [StrapSamples, SleepSessions, StoredWorkouts, DeviceTotals, SyncMeta],
)
class StrapReader extends DatabaseAccessor<LocalStore> with _$StrapReaderMixin {
  /// Built by drift as `store.strapReader`.
  StrapReader(super.db);

  /// Everything the strap measured on [day] (`YYYY-MM-DD`).
  ///
  /// Never throws for missing data — an unsynced day is a [DeviceDay] full of
  /// withholds, which is a real answer. It throws only if the database itself
  /// fails, which is not "no data" and must not be dressed as it (Standards §1).
  Future<DeviceDay> day(String day) async {
    final totals = await _totals(day);
    final series = await _heartRateSeries(day);
    final night = await _lastNightOnOrBefore(day);

    return DeviceDay(
      date: day,
      steps: totals == null
          ? notMeasured('steps')
          : Present<int>(totals.steps),
      distanceKm: totals == null
          ? notMeasured('distance')
          : Present<double>(totals.distanceM / 1000),
      deviceCalories: totals == null
          ? notMeasured('calories')
          : Present<int>(totals.calories),
      stepsReadAt: totals == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(totals.readAtMs),
      heartRate: series.isEmpty
          ? notMeasured('heart rate')
          : Present<double>(series.last.value),
      heartRateSeries: series,
      lastNight: night == null ? notMeasured('sleep') : Present<DeviceNight>(night),
      metrics: [for (final stream in kDeviceStreams) await _metric(stream, day)],
      workouts: await _workouts(day),
      sync: await _syncStamp(),
      batteryPercent: int.tryParse(await _meta(SyncKeys.batteryPercent) ?? ''),
    );
  }

  /// One [SyncMeta] value, or null when it was never written.
  Future<String?> _meta(String name) async {
    final query = select(syncMeta)..where((row) => row.name.equals(name));
    return (await query.getSingleOrNull())?.value;
  }

  Future<StoredDeviceTotals?> _totals(String day) {
    final query = select(deviceTotals)..where((row) => row.day.equals(day));
    return query.getSingleOrNull();
  }

  Future<List<DevicePoint>> _heartRateSeries(String day) async {
    final query = select(strapSamples)
      ..where((row) => row.day.equals(day) & row.metric.equals(kHeartRateMetric))
      ..orderBy([(row) => OrderingTerm.asc(row.tsMs)]);
    return [
      for (final row in await query.get())
        DevicePoint(DateTime.fromMillisecondsSinceEpoch(row.tsMs), row.value),
    ];
  }

  Future<DeviceMetric> _metric(DeviceStream stream, String day) async {
    final query = select(strapSamples)
      ..where((row) => row.day.equals(day) & row.metric.equals(stream.metric))
      ..orderBy([(row) => OrderingTerm.asc(row.tsMs)]);
    final rows = await query.get();
    if (rows.isEmpty) {
      return DeviceMetric(
        stream: stream,
        reading: notMeasured(stream.label.toLowerCase()),
        measuredAt: null,
        sampleCount: 0,
      );
    }
    // The LATEST sample, not a mean over the day. A mean is an aggregate the
    // owner never wore — and the server's baselines are the thing that compares
    // days honestly, with a window and an instrument. This is "the last thing
    // the sensor said", stamped with when it said it.
    final latest = rows.last;
    return DeviceMetric(
      stream: stream,
      reading: Present<double>(latest.value),
      measuredAt: DateTime.fromMillisecondsSinceEpoch(latest.tsMs),
      sampleCount: rows.length,
    );
  }

  /// The newest sleep record starting on or before [day].
  ///
  /// "On or before" rather than "on", because a night that began at 23:40 is
  /// filed under yesterday and is still last night. Naps are excluded — the card
  /// is about the night, and a 20-minute afternoon nap ranking as the newest
  /// record would replace it.
  Future<DeviceNight?> _lastNightOnOrBefore(String day) async {
    final query = select(sleepSessions)
      ..where((row) => row.day.isSmallerOrEqualValue(day) & row.isNap.equals(false))
      ..orderBy([(row) => OrderingTerm.desc(row.startMs)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }
    final stages = _stages(row.stagesJson);
    final start = DateTime.fromMillisecondsSinceEpoch(row.startMs);
    return DeviceNight(
      start: stages.isEmpty ? start : stages.first.start,
      end: stages.isEmpty ? start : stages.last.end,
      isNap: row.isNap,
      remMin: row.remMin,
      lightMin: row.lightMin,
      deepMin: row.deepMin,
      wakeMin: row.wakeMin,
      deviceScore: row.score,
      avgHr: row.avgHr,
      stages: stages,
    );
  }

  /// `[[startMs, endMs, type], …]` back into spans.
  ///
  /// A malformed entry is skipped rather than defaulted: a stage span we cannot
  /// read is not a light-sleep span, and drawing it as one would put a fabricated
  /// block in a hypnogram.
  static List<DeviceStage> _stages(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final entry in decoded)
        if (entry is List && entry.length >= 3 && entry.every((v) => v is int))
          DeviceStage(
            start: DateTime.fromMillisecondsSinceEpoch(entry[0] as int),
            end: DateTime.fromMillisecondsSinceEpoch(entry[1] as int),
            kind: _stageKind(entry[2] as int),
          ),
    ];
  }

  /// The device's stage codes, as `SleepStageSeg.kind` names them.
  static String _stageKind(int type) => switch (type) {
    4 => 'light',
    5 => 'deep',
    8 => 'rem',
    7 => 'awake',
    _ => 'any',
  };

  Future<List<DeviceWorkout>> _workouts(String day) async {
    final query = select(storedWorkouts)
      ..where((row) => row.day.equals(day))
      ..orderBy([(row) => OrderingTerm.desc(row.startMs)]);
    return [
      for (final row in await query.get())
        DeviceWorkout(
          start: DateTime.fromMillisecondsSinceEpoch(row.startMs),
          sportType: row.sportType,
          duration: Duration(seconds: row.durationSec),
          calories: row.calories,
          avgHr: row.avgHr,
          maxHr: row.maxHr,
        ),
    ];
  }

  Future<DeviceSyncStamp> _syncStamp() async {
    return DeviceSyncStamp(
      lastCompleteSync: _instant(await _meta(SyncKeys.lastCompleteSyncMs)),
      lastAttempt: _instant(await _meta(SyncKeys.lastAttemptMs)),
      lastOutcomeId: await _meta(SyncKeys.lastOutcome),
    );
  }

  static DateTime? _instant(String? ms) {
    final value = int.tryParse(ms ?? '');
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }
}
