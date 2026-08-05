/// What the owner actually did today: workouts, meditation, and an open fast.
///
/// `read/routine.py::routine_today`, and **legacy referenced it in no file at
/// all** — the server has been computing and sending it to nobody.
///
/// Everything here is a **log of something that happened**, not a derived
/// judgement, which is why none of it is a `Reading`: there is no gate to
/// refuse, and an empty day is not a refusal. [isEmpty] is the whole honesty
/// contract for this block — a day with nothing logged renders nothing, never a
/// heading over an empty list.
library;

import 'package:meta/meta.dart';

/// One session the strap or a manual log recorded today.
@immutable
class RoutineEvent {
  /// A logged session.
  const RoutineEvent({
    required this.kind,
    required this.type,
    required this.startIso,
    required this.durationMin,
    required this.source,
  });

  /// Parses one entry of `routine.workouts`.
  factory RoutineEvent.fromJson(Map<String, Object?> json) {
    return RoutineEvent(
      kind: json['kind'] as String? ?? 'workout',
      type: json['type'] as String?,
      startIso: json['start_iso'] as String?,
      durationMin: (json['duration_min'] as num?)?.toInt(),
      source: json['source'] as String?,
    );
  }

  /// `workout`.
  final String kind;

  /// The sport, as the server named it — `Outdoor run`.
  final String? type;

  /// When it started, ISO-8601.
  final String? startIso;

  /// How long it ran. The server drops anything under ten minutes.
  final int? durationMin;

  /// Where it came from — `strap`, or a manual log. Named on the wire because
  /// the two are different instruments and a session's provenance is part of it.
  final String? source;
}

/// A fast that has begun and not yet ended.
@immutable
class OpenFast {
  /// An in-progress fast.
  const OpenFast({required this.startIso, required this.elapsedMin});

  /// Parses `routine.open_fast`, or null when none is running.
  static OpenFast? maybe(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final elapsed = (raw['elapsed_min'] as num?)?.toInt();
    if (elapsed == null) {
      return null;
    }
    return OpenFast(startIso: raw['start_iso'] as String?, elapsedMin: elapsed);
  }

  /// When it began, ISO-8601.
  final String? startIso;

  /// How long it has been running, in minutes. The server computes this against
  /// its own clock, which is why the app does not recompute it from [startIso]
  /// — two answers to "how long" is one of them being wrong.
  final int elapsedMin;
}

/// Today's routine: sessions, meditation, and any open fast.
@immutable
class Routine {
  /// Builds a day. Prefer [Routine.fromJson].
  const Routine({
    required this.workouts,
    required this.meditationCount,
    required this.meditationMinutes,
    required this.openFast,
  });

  /// Parses the `routine` block. Never null — an absent block is an empty day,
  /// and [isEmpty] is what decides whether anything is drawn.
  factory Routine.fromJson(Map<String, Object?> json) {
    final meditation = json['meditation_today'] is Map<String, Object?>
        ? json['meditation_today']! as Map<String, Object?>
        : const <String, Object?>{};
    return Routine(
      workouts: [
        for (final entry in (json['workouts'] as List? ?? const []))
          if (entry is Map<String, Object?>) RoutineEvent.fromJson(entry),
      ],
      meditationCount: (meditation['count'] as num?)?.toInt() ?? 0,
      meditationMinutes: (meditation['minutes'] as num?)?.toInt() ?? 0,
      openFast: OpenFast.maybe(json['open_fast']),
    );
  }

  /// Today's sessions, newest first.
  final List<RoutineEvent> workouts;

  /// How many meditation entries were logged today.
  final int meditationCount;

  /// Their total minutes.
  final int meditationMinutes;

  /// A fast still running, or null.
  final OpenFast? openFast;

  /// Whether there is anything at all to say. **A day with nothing logged draws
  /// nothing** — no card, no heading, no "nothing yet" placeholder.
  bool get isEmpty =>
      workouts.isEmpty && meditationCount == 0 && openFast == null;
}
