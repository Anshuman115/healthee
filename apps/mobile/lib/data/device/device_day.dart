/// One day, as the strap measured it — the whole of what Today can honestly show.
///
/// ## The two halves, and why they are in one type
///
/// Every field is either something a sensor produced ([steps], [heartRate],
/// [lastNight], [metrics], [workouts]) or a refusal standing where a server
/// number would be ([recovery], [sleepHealth], [vo2max], [biologicalAge]). They
/// live together because the SCREEN is one thing and the owner reads it top to
/// bottom: a Today that quietly omitted every derived card would look complete
/// and be missing four judgements, which is precisely the silence this product
/// is built against.
///
/// The refusals are not placeholders and are not "coming soon" copy. They are
/// [Withheld] readings carrying a real reason id, built by
/// `data/honesty/server_owned.dart`, and they render through the same
/// `WithheldCard` a production withhold renders through. When the push and the
/// `/api/today` read land, those fields change *source*; nothing about their
/// shape or their rendering changes.
///
/// ## Nothing here is computed
///
/// The only arithmetic in this file and the types it holds is summing the
/// device's own stage minutes ([DeviceNight.asleepMin]) and picking the latest
/// sample in a series. No baseline, no z-score, no cutoff, no model. If a future
/// field here needs a formula, it belongs on the server.
library;

import 'package:healthee/data/device/device_metric.dart';
import 'package:healthee/data/device/device_night.dart';
import 'package:healthee/data/device/device_workout.dart';
import 'package:healthee/data/honesty/device_absence.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/honesty/server_owned.dart';
import 'package:meta/meta.dart';

/// One point in a plotted series: a value the strap recorded at an instant.
@immutable
class DevicePoint {
  /// A measured value at [at].
  const DevicePoint(this.at, this.value);

  /// When the strap recorded it.
  final DateTime at;

  /// The value, in the metric's own unit.
  final double value;
}

/// What the app knows about its own syncing, for the data-health strip.
///
/// [lastCompleteSync] and [lastAttempt] are separate fields because they are
/// separate facts, and conflating them is how a screen shows a partial pull as
/// an up-to-date one. `StrapWriter.stampAttempt` is the only writer of either.
@immutable
class DeviceSyncStamp {
  /// Read out of [SyncMeta] by the store.
  const DeviceSyncStamp({
    this.lastCompleteSync,
    this.lastAttempt,
    this.lastOutcomeId,
  });

  /// Nothing has ever been synced on this phone.
  const DeviceSyncStamp.never() : this();

  /// When a sync last finished **completely**. Null until one has.
  final DateTime? lastCompleteSync;

  /// When a sync was last attempted, complete or not.
  final DateTime? lastAttempt;

  /// The last attempt's outcome id — `complete`, `partial`, `failed`.
  final String? lastOutcomeId;

  /// True when the last attempt ended in something less than a full pull.
  ///
  /// The screen uses this to say so out loud. An attempt that half-worked and
  /// says nothing is indistinguishable from one that worked.
  bool get lastAttemptIncomplete =>
      lastOutcomeId != null && lastOutcomeId != 'complete';
}

/// Everything the strap measured on one calendar day.
@immutable
class DeviceDay {
  /// Built by [package:healthee/data/store/strap_reader].
  const DeviceDay({
    required this.date,
    required this.steps,
    required this.distanceKm,
    required this.deviceCalories,
    required this.stepsReadAt,
    required this.heartRate,
    required this.heartRateSeries,
    required this.lastNight,
    required this.metrics,
    required this.workouts,
    required this.sync,
    required this.batteryPercent,
  });

  /// A day with nothing in it — a phone that has never synced.
  ///
  /// Every measured field withholds for the same honest reason, and every
  /// derived field withholds for its own. Distinct from a *failed read*, which
  /// is an `AsyncError` and renders with a retry.
  factory DeviceDay.empty(String date) => DeviceDay(
    date: date,
    steps: notMeasured('steps'),
    distanceKm: notMeasured('distance'),
    deviceCalories: notMeasured('calories'),
    stepsReadAt: null,
    heartRate: notMeasured('heart rate'),
    heartRateSeries: const [],
    lastNight: notMeasured('sleep'),
    metrics: [
      for (final stream in kDeviceStreams)
        DeviceMetric(
          stream: stream,
          reading: notMeasured(stream.label.toLowerCase()),
          measuredAt: null,
          sampleCount: 0,
        ),
    ],
    workouts: const [],
    sync: const DeviceSyncStamp.never(),
    batteryPercent: null,
  );

  /// The owner-local calendar date, `YYYY-MM-DD`.
  final String date;

  /// Steps from the strap's own `0x0016` since-midnight counter (#121).
  ///
  /// **Not** the sum of the per-minute stream, which this firmware freezes
  /// mid-day and backfills with `0xFF`. Withheld when the strap did not answer,
  /// because "the strap did not say" and "the owner took no steps" are opposite
  /// claims and a zero would assert the second.
  final Reading<int> steps;

  /// Distance since midnight, from the same counter.
  final Reading<double> distanceKm;

  /// Calories since midnight **as the strap computed them**. Labelled as the
  /// strap's wherever it is shown; the product's energy model is the server's.
  final Reading<int> deviceCalories;

  /// When the counter was last read. The counter is "since midnight", so one
  /// read at 09:00 is a claim about nine hours — the screen must say when.
  final DateTime? stepsReadAt;

  /// The most recent heart-rate sample of the day.
  final Reading<double> heartRate;

  /// Today's heart-rate samples in order, for the day chart. Empty when none.
  final List<DevicePoint> heartRateSeries;

  /// The most recent sleep record ending on or before this day.
  final Reading<DeviceNight> lastNight;

  /// One entry per stream in [kDeviceStreams], in that order, always present —
  /// a stream with no samples is a withheld row, never a missing one. A row that
  /// disappears on a bad day makes the list shorter and the absence invisible.
  final List<DeviceMetric> metrics;

  /// Sessions recorded on this day, newest first.
  final List<DeviceWorkout> workouts;

  /// What the app knows about its own syncing.
  final DeviceSyncStamp sync;

  /// Strap battery at the last sync, or null when it was never read.
  final int? batteryPercent;

  /// Recovery — **the server's**, and therefore withheld here.
  Reading<double> get recovery => serverDerived<double>('Recovery');

  /// The four-dimension sleep judgement — the server's.
  Reading<double> get sleepHealth => serverDerived<double>('Sleep health');

  /// Sleep debt — the server's.
  Reading<double> get sleepDebt => serverDerived<double>('Sleep debt');

  /// The fitness estimate and its instrument — the server's.
  Reading<double> get vo2max => serverDerived<double>('VO₂max');

  /// The motivational estimate — the server's.
  Reading<double> get biologicalAge => serverDerived<double>('Biological age');

  /// True when the strap has told us nothing at all about this day.
  ///
  /// Drives one honest empty state rather than nine identical withheld cards,
  /// which is what a never-synced phone would otherwise show.
  bool get hasNothing =>
      !steps.hasValue &&
      !heartRate.hasValue &&
      !lastNight.hasValue &&
      workouts.isEmpty &&
      metrics.every((metric) => !metric.reading.hasValue);
}
