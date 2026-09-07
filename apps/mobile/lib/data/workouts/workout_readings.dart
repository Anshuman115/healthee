/// One workout's figures as [Reading]s — including the ones that are not there.
///
/// ## Why this file exists at all
///
/// `/api/activity/workout` is the one payload in this app that carries **no
/// honesty envelope**. `read/workout.py` writes a derived metric into its
/// `metrics` object only when that metric's inputs existed, and simply omits it
/// otherwise: no `withheld`, no `reason`, no sentence. So `readingFrom` — the
/// single site that folds a server block into a [Reading] — has nothing to fold,
/// and the screen would be back to the nullable fields `reading.dart` exists to
/// replace, with a silent gap wherever an input was missing. The pre-v02 screen
/// did exactly that: `if (detail.trimp != null) Text(...)`, and a session with no
/// TRIMP said nothing about why.
///
/// ## The rule that keeps this honest rather than inventive
///
/// **Every reason here is read off the payload the app is already holding**, not
/// guessed. `read/workout.py` states each precondition in code, and all but one
/// of them is visible on the wire:
///
/// ```text
///   pace, speed        distance > 50 m AND a duration   → both in `workout`
///   cal/min            calories AND a duration          → both in `workout`
///   zones              an HRmax estimate                → `hrmax`
///   %HRmax             an HRmax estimate + the summary  → `hrmax`, `workout`
///   HR drift           ≥ 6 heart-rate samples           → `hr_series`
///   session TRIMP      HRmax, resting HR, sex, samples  → only partly visible
/// ```
///
/// TRIMP is the exception and it is treated as one: its sentence names all four
/// of its inputs rather than pretending to know which of them was missing. Where
/// the app genuinely cannot say, it falls back to [unexplainedAbsenceMessage] —
/// the shared sentence for "no value and no reason", which `envelope.dart` wrote
/// precisely so nobody would be tempted to make a nicer one up.
///
/// ## What is deliberately NOT here
///
/// No remedy is invented. `withheld_block`'s second-person "do this and it comes
/// back" is the server's to write, and it did not write one; a *"sync and it will
/// appear"* on a treadmill run with no GPS would be an instruction that cannot
/// work. A truthful absence with no action beats an action that is not one.
library;

import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/envelope.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/workouts/workout_detail.dart';
import 'package:meta/meta.dart';

/// The minimum recorded distance `read/workout.py` will publish a pace for.
const int kPaceMinimumMetres = 50;

/// The heart-rate samples `read/workout.py` needs before it compares halves.
const int kDriftMinimumSamples = 6;

/// One session's readings, each carrying its own absence.
@immutable
class WorkoutReadings {
  /// Wraps [detail]. Cheap — every getter is computed on demand.
  const WorkoutReadings(this.detail);

  /// The parsed payload. Untouched by this class.
  final WorkoutDetail detail;

  /// Kilometres, from the strap's recorded metres.
  Reading<double> get distanceKm => _read(
    detail.workout.distanceM == null ? null : detail.workout.distanceM! / 1000,
    'no_recorded_distance',
    'The strap recorded no distance for this session, so there is nothing to '
        'convert into kilometres.',
  );

  /// Minutes, as the strap timed them.
  Reading<int> get durationMin => _read(
    detail.workout.durationMin,
    'no_recorded_duration',
    'The strap recorded no duration for this session.',
  );

  /// Minutes per kilometre, as the server computed them.
  Reading<double> get pace =>
      _read(detail.paceMinPerKm, 'pace_needs_distance_and_duration', _paceWhy);

  /// Kilometres per hour, from the same two inputs as [pace].
  Reading<double> get speed =>
      _read(detail.speedKmh, 'speed_needs_distance_and_duration', _paceWhy);

  /// The session's average heart rate, as the strap summarised it.
  Reading<int> get avgHr =>
      _read(detail.workout.avgHr, 'no_heart_rate_summary', _summaryWhy);

  /// Its peak.
  Reading<int> get maxHr =>
      _read(detail.workout.maxHr, 'no_heart_rate_summary', _summaryWhy);

  /// The minute-by-minute profile.
  ///
  /// An empty list is an absence rather than a series of length zero: the
  /// summary row and the samples upload separately, so a session can exist for
  /// a while with nothing inside it.
  Reading<List<DevicePoint>> get heartRate => _read(
    detail.heartRate.isEmpty ? null : detail.heartRate,
    'no_heart_rate_samples',
    'No heart-rate samples fell inside this session. A workout summary can '
        'reach the server before the minutes behind it do.',
  );

  /// Minutes per heart-rate zone.
  ///
  /// **All-zero is a reading, not a gap** — it means no minute reached 50 % of
  /// HRmax, which is a measurement about an easy session. The absence is the
  /// missing HRmax the zones are cut against, and that is what is checked.
  Reading<List<int>> get zones => _read(
    detail.hrmax == null || detail.zones.isEmpty ? null : detail.zones,
    'hrmax_unavailable',
    'Zone minutes are cut against an HRmax estimate, and the server sent none '
        'for this session.',
  );

  /// How many of the session's minutes landed in a zone.
  int get classifiedMinutes =>
      detail.zones.fold<int>(0, (total, minutes) => total + minutes);

  /// The session's Banister TRIMP.
  Reading<double> get trimp => _read(
    detail.trimp,
    'trimp_inputs_missing',
    'A session load needs your HRmax, your resting heart rate and your sex on '
        'the server, together with heart-rate samples inside the session.',
  );

  /// The strap's own calorie count for the session.
  Reading<int> get calories => _read(
    detail.workout.calories?.round(),
    'no_strap_calories',
    'The strap recorded no calorie figure for this session.',
  );

  /// Second half minus first half, in beats per minute.
  Reading<double> get hrDrift => _read(
    detail.hrDriftBpm,
    'drift_needs_six_minutes',
    'Comparing the halves of a session needs at least '
        '$kDriftMinimumSamples recorded heart-rate minutes.',
  );

  /// The average, as a percentage of HRmax.
  Reading<double> get avgPercentHrmax =>
      _read(detail.averagePercentHrmax, 'hrmax_unavailable', _percentWhy);

  /// The peak, on the same scale.
  Reading<double> get maxPercentHrmax =>
      _read(detail.maxPercentHrmax, 'hrmax_unavailable', _percentWhy);

  static const String _paceWhy =
      'A pace needs both a recorded distance and a duration. The server '
      'publishes one only for a session that covered more than '
      '$kPaceMinimumMetres m.';

  static const String _summaryWhy =
      'The strap sent no heart-rate summary for this session.';

  static const String _percentWhy =
      'A share of HRmax needs an HRmax estimate, and the server sent none for '
      'this session.';

  /// [value] as a [Present], or a [Withheld] carrying [reason] and [message].
  ///
  /// An empty [message] cannot happen from this file, and if it ever did the
  /// shared "no value and no reason" sentence is used rather than a blank one —
  /// `envelope.dart` makes the same call at the same boundary.
  static Reading<T> _read<T extends Object>(
    T? value,
    String reason,
    String message,
  ) {
    if (value != null) {
      return Present<T>(value);
    }
    return message.isEmpty
        ? Withheld<T>(
            const Disclosure(
              reason: unexplainedAbsenceReason,
              message: unexplainedAbsenceMessage,
            ),
          )
        : Withheld<T>(Disclosure(reason: reason, message: message));
  }
}
