/// A workout summary as the strap recorded it.
///
/// **Ported verbatim** from the `Workout` class in
/// `~/projects/healthee-legacy/app/lib/ble/workout_parser.dart`, minus its
/// `toJson`/`fromJson` pair — see `sleep_session.dart` for why the legacy
/// store's serialisation does not come across.
///
/// The field map is VERIFIED against a real workout (2026-05-01: duration
/// 6:49 = 409 s, 53 kcal, avg HR 122) — not guessed. `workout_parser.dart`
/// carries the protobuf field table those values were read through.
library;

import 'package:meta/meta.dart';

/// One decoded workout summary.
@immutable
class Workout {
  /// Every field is read straight from the protobuf summary.
  const Workout({
    required this.start,
    required this.sportType,
    required this.durationSec,
    required this.calories,
    required this.avgHr,
    required this.maxHr,
    required this.minHr,
  });

  /// When the workout began.
  final DateTime start;

  /// The device's sport-type code.
  final int sportType;

  /// Duration in seconds.
  final int durationSec;

  /// Calories as the DEVICE reported them.
  ///
  /// Not the app's number: CLAUDE.md pins free-living energy to the
  /// MET-by-state model on the server. This field is the strap's own figure,
  /// carried unaltered so the server can decide what to do with it.
  final int calories;

  /// Average heart rate over the workout.
  final int avgHr;

  /// Peak heart rate.
  final int maxHr;

  /// Lowest heart rate.
  final int minHr;

  @override
  String toString() =>
      'workout ${start.toIso8601String()} type=$sportType ${durationSec}s '
      '$calories kcal hr=$avgHr/$maxHr/$minHr';
}
