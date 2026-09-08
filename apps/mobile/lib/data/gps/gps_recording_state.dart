/// What a recording reads right now — including the track itself.
///
/// ## The track is here because it was the bug
///
/// This class used to carry a fix COUNT and a distance and nothing else, so the
/// recorder screen could say "412 fixes, 3.10 km" and could not draw a single
/// metre of them. The coordinates went to SQLite on the way past and were never
/// held anywhere the UI could reach, which is why that screen had no map: not a
/// missing painter, a missing measurement.
///
/// [points] is now derived from [track] rather than stored beside it. One
/// definition: a count that could disagree with the coordinates it counts is a
/// second, quieter version of the same defect.
///
/// ## The copy per fix, and why it is affordable
///
/// [GpsRun] rebuilds this object on every accepted fix, so appending is an O(n)
/// list copy and a whole recording is O(n²): at the 28,800-fix ceiling that is
/// ~414M element copies spread over eight hours, tens of microseconds per fix.
/// It sits behind an awaited SQLite write on the same path, which costs orders
/// of magnitude more. The alternative — mutating one shared list — would make
/// two states compare equal while holding different tracks, and every
/// `shouldRepaint` in the app is identity-based.
library;

import 'package:healthee/data/gps/route_point.dart';

/// A recording's live reading: its identity, its clock, and its track so far.
class GpsRecordingState {
  /// Builds a reading. [track] is oldest fix first.
  const GpsRecordingState({
    this.id,
    this.start,
    this.end,
    this.recording = false,
    this.busy = false,
    this.track = const <RoutePoint>[],
    this.distanceM = 0,
    this.error,
  });

  /// The recording's client-side id, once one has been begun.
  final String? id;

  /// When it started, in UTC.
  final DateTime? start;

  /// When it stopped, in UTC. Null while it is still running.
  final DateTime? end;

  /// Whether fixes are still being accepted.
  final bool recording;

  /// Whether a start/stop is in flight — the control is a spinner, not a button.
  final bool busy;

  /// Every accepted fix, oldest first. The same coordinates that went to disk.
  final List<RoutePoint> track;

  /// Distance along the track, from the phone's own geodesy.
  final double distanceM;

  /// Why the recording stopped, when it stopped for a reason.
  final String? error;

  /// How many fixes have been accepted — [track]'s own length, never a
  /// second counter that could drift from it.
  int get points => track.length;

  /// Time on the clock at [now], frozen at [end] once the recording has stopped.
  Duration elapsedAt(DateTime now) {
    if (start == null) return Duration.zero;
    final duration = (end ?? now).difference(start!);
    return duration.isNegative ? Duration.zero : duration;
  }

  /// Minutes per kilometre, or null while there is no distance to divide by.
  double? paceAt(DateTime now) => distanceM <= 0
      ? null
      : elapsedAt(now).inSeconds / 60 / (distanceM / 1000);
}
