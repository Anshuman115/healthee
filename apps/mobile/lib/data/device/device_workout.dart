/// One recorded session, with the device's own heart-rate and calorie figures.
library;

import 'package:meta/meta.dart';

/// A workout summary as the strap recorded it.
@immutable
class DeviceWorkout {
  /// Built by [package:healthee/data/store/strap_reader].
  const DeviceWorkout({
    required this.start,
    required this.sportType,
    required this.duration,
    required this.calories,
    required this.avgHr,
    required this.maxHr,
  });

  /// When it began.
  final DateTime start;

  /// The device's sport-type code.
  final int sportType;

  /// How long it ran.
  final Duration duration;

  /// Calories **as the device reported them**.
  ///
  /// Carried unaltered and labelled as the strap's, never as Healthee's: the
  /// energy model this product stands behind is MET-by-state and it runs on the
  /// server (CLAUDE.md). Two calorie numbers with one label would be the
  /// canonical-definition rule broken in the most expensive place.
  final int calories;

  /// Average heart rate over the session.
  final int avgHr;

  /// Peak heart rate.
  final int maxHr;

  /// The sport's name, or a plain code when the strap used one we have not seen.
  ///
  /// The unknown case says the code out loud rather than guessing a nearby
  /// sport: "Activity (type 61)" is honest and searchable, "Walk" would be a
  /// made-up fact about how the owner spent an hour. Codes are the strap's own,
  /// confirmed against recorded sessions.
  String get sportLabel => switch (sportType) {
    1 => 'Outdoor run',
    6 => 'Walk',
    8 => 'Treadmill',
    9 => 'Outdoor cycle',
    10 => 'Indoor cycle',
    16 => 'Free training',
    60 => 'Yoga',
    _ => 'Activity (type $sportType)',
  };
}
