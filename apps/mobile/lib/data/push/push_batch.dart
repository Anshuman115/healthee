/// What one `POST /ingest/helio` carries, and the shape it goes out in.
///
/// This file is the mobile half of a wire contract whose other half is
/// `apps/server/src/healthee/ingest/models.py`. Every key below was read off
/// those pydantic models rather than remembered: `HelioPayload` has
/// `samples` · `sleep` · `workouts` · `daily_totals` · `profile`, each list
/// defaulting to empty and `profile` to null, and every model is
/// `extra="ignore"` so a key we do not send is simply a key the server does not
/// see.
///
/// ## Why the metric names are translated here and nowhere else
///
/// The strap's parser emits its own vocabulary (`temperature_c`, `spo2_sleep`,
/// `steps`); the server accepts a fixed whitelist (`ALLOWED_METRICS` in the same
/// module). The two are not the same set and never were. [kPushMetricNames] is
/// the one map between them, and a metric absent from it is deliberately **not
/// sent** — `resting_hr` and `max_hr` are things the server derives from raw
/// `hr`, so pushing the strap's own version would be a second definition of a
/// number the server already owns (CLAUDE.md's first hard rule).
///
/// The server drops an unknown metric and counts it (`samples_rejected`) rather
/// than rejecting the push, which is the right behaviour for a newer app against
/// an older server — but it is not a licence to send noise, because a dropped
/// row still looks like a sent row from here.
///
/// ## What is NOT in the payload
///
/// **`profile`.** It is optional server-side and this app has no profile to
/// send: pairing collects a MAC and an AUTHKEY, not a date of birth. Sending a
/// half-built profile would move the owner's age, and the age is an input to
/// VO₂max and biological age. Nothing is better than nearly.
///
/// **The strap's MAC and AUTHKEY.** They are per-owner secrets that live in the
/// platform keystore and are used to talk to the *strap*. They have no business
/// on a request to our API and `test/push/push_secrecy_test.dart` asserts the
/// serialised body contains neither.
library;

import 'dart:convert';

import 'package:healthee/data/store/local_store.dart';
import 'package:meta/meta.dart';

/// Strap metric name → the server's canonical name.
///
/// Mirrors the legacy app's `_metricMap` (`ble/helio_api.dart`), which is the
/// map the shipped server was built against, and every value is a member of
/// `ingest/models.py`'s `ALLOWED_METRICS`.
///
/// Two strap streams collapse onto one server metric: `spo2` (spot readings) and
/// `spo2_sleep` (the overnight series) are both blood oxygen, and the server
/// windows them itself. That is a translation, not a merge of definitions.
const Map<String, String> kPushMetricNames = <String, String>{
  'hr': 'hr',
  'hrv': 'hrv',
  'spo2': 'spo2',
  'spo2_sleep': 'spo2',
  'temperature_c': 'skin_temp_c',
  'respiratory_rate': 'respiratory_rate',
  'stress': 'stress',
  'steps': 'steps_per_minute',
};

/// One page of unsent measurements, straight off the local tier.
///
/// Holds drift's own row classes rather than a re-modelled copy of them. They
/// are already typed models at the storage boundary (Standards §3), and a second
/// set of field names between the table and the wire is one more place for
/// `deep_min` to become `deepMin` incorrectly.
@immutable
class PushBatch {
  /// Built by `PushReader.pending`.
  const PushBatch({
    required this.samples,
    required this.nights,
    required this.workouts,
    required this.totals,
  });

  /// An empty page — nothing is waiting.
  const PushBatch.nothing()
    : samples = const [],
      nights = const [],
      workouts = const [],
      totals = const [];

  /// Unsent per-metric samples, oldest first.
  final List<StoredSample> samples;

  /// Unsent sleep records — nights and naps alike.
  final List<StoredSleepSession> nights;

  /// Unsent workout summaries.
  final List<StoredWorkout> workouts;

  /// Unsent since-midnight counters, one per day.
  ///
  /// **The row that must never be dropped.** `0x0016` is the authoritative daily
  /// step total; the per-minute stream is frozen or incomplete on this firmware.
  /// #121 cost 142 production days of real step counts because this measurement
  /// had nowhere durable to land, and a push that quietly omitted it would
  /// recreate the loss with the table sitting right there.
  final List<StoredDeviceTotals> totals;

  /// How many rows this page carries, across every kind.
  int get rowCount =>
      samples.length + nights.length + workouts.length + totals.length;

  /// Whether there is anything to send at all.
  bool get isEmpty => rowCount == 0;

  /// The request body, exactly as `HelioPayload` parses it.
  ///
  /// Samples whose metric is not in [kPushMetricNames] are dropped here, so the
  /// count of rows we mark as pushed can exceed the count of samples on the
  /// wire. That is correct: a row we have decided never to send is settled, not
  /// pending, and leaving it unmarked would make it a permanent page-one
  /// resident that stalls the pager forever.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'samples': <Map<String, Object?>>[
        for (final sample in samples)
          if (kPushMetricNames[sample.metric] case final String canonical)
            <String, Object?>{
              'metric': canonical,
              'ts': sample.tsMs,
              'value': sample.value,
            },
      ],
      'sleep': <Map<String, Object?>>[
        for (final night in nights)
          if (_stagesOf(night) case final List<List<int>> stages)
            if (stages.isNotEmpty) _nightJson(night, stages),
      ],
      'workouts': <Map<String, Object?>>[
        for (final workout in workouts)
          <String, Object?>{
            'start_ts': workout.startMs,
            'sport': workout.sportType,
            'duration_s': workout.durationSec,
            'calories': workout.calories,
            'avg_hr': workout.avgHr,
            'max_hr': workout.maxHr,
            'min_hr': workout.minHr,
          },
      ],
      'daily_totals': <Map<String, Object?>>[
        for (final total in totals)
          <String, Object?>{
            // `DailyTotalIn.day` is an owner-local `YYYY-MM-DD`, which is
            // exactly what the column already holds — no conversion, therefore
            // no timezone, therefore nothing to get wrong.
            'day': total.day,
            'steps': total.steps,
            'distance_m': total.distanceM,
            'calories': total.calories,
            // WHEN WE ASKED THE STRAP. This app has always recorded it —
            // `DeviceTotals.readAtMs`, whose own comment says why ("a counter
            // read at 09:00 is a claim about nine hours, not about a day") —
            // and `PushReader.markPushed` keys the pending marker on it so a
            // newer reading that overlapped a push is not marked sent.
            //
            // It was never sent. The server had no field for it and substituted
            // the ARRIVAL instant, so the partial-day caveat quoted the wrong
            // moment, and — worse — suppressed itself entirely whenever a push
            // crossed local midnight, which is the normal case because
            // auto-sync fires on a foreground transition. The counter is
            // preferred over the per-minute sum unconditionally, so nine hours
            // served as a whole day with nothing said (write-path audit A1).
            //
            // A server older than `0019` ignores this key (`extra="ignore"`);
            // a server newer than this app records the read time as UNKNOWN and
            // says so, rather than inventing one.
            'read_at': total.readAtMs,
          },
      ],
    };
  }

  static Map<String, Object?> _nightJson(
    StoredSleepSession night,
    List<List<int>> stages,
  ) {
    return <String, Object?>{
      // The hypnogram's own bounds, not the record's summary minutes — the same
      // choice the shipped client makes, and the one `SleepIn` documents: the
      // per-minute stage stream is materialised from `stages`.
      'start_ts': stages.first[0],
      'end_ts': stages.last[1],
      'kind': night.isNap ? 'nap' : 'main',
      'score': night.score,
      'avg_hr': night.avgHr,
      'rem_min': night.remMin,
      'light_min': night.lightMin,
      'deep_min': night.deepMin,
      'wake_min': night.wakeMin,
      'stages': stages,
    };
  }

  /// `[[startMs, endMs, type], …]` back out of the stored JSON.
  ///
  /// A malformed entry is skipped rather than defaulted, for the reason
  /// `StrapReader._stages` gives: a span we cannot read is not a light-sleep
  /// span, and sending it as one would put a fabricated block in the server's
  /// hypnogram.
  static List<List<int>> _stagesOf(StoredSleepSession night) {
    final decoded = jsonDecode(night.stagesJson);
    if (decoded is! List) {
      return const [];
    }
    return <List<int>>[
      for (final entry in decoded)
        if (entry is List && entry.length >= 3 && entry.every((v) => v is int))
          <int>[entry[0] as int, entry[1] as int, entry[2] as int],
    ];
  }
}
