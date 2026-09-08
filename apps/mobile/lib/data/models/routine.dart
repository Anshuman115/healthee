/// What the owner actually did today: workouts, meditation, and an open fast.
///
/// `read/routine.py::routine_today`, and **legacy referenced it in no file at
/// all** — the server has been computing and sending it to nobody.
///
/// Everything here is a **log of something that happened**, not a derived
/// judgement, which is why none of it is a `Reading`: there is no gate to
/// refuse, and an empty day is not a refusal. [Routine.isEmpty] is the whole honesty
/// contract for this block — a day with nothing logged renders nothing, never a
/// heading over an empty list.
///
/// ## `logs_summary`, and the day that rendered as empty while the wire said otherwise
///
/// `read/routine.py` has always shipped `logs_summary` — the per-kind `{count, total}`
/// roll-up of the day's manual entries — and `grep logs_summary apps/mobile/lib` returned
/// nothing. That was not merely dead weight: [Routine.isEmpty] was
/// `workouts.isEmpty && meditationCount == 0 && openFast == null`, so a day whose only
/// entry was caffeine, or hydration, or any kind but meditation drew **no journal panel
/// at all** while the payload was explicitly reporting that entry.
///
/// Nothing was fabricated — the panel was silent, not wrong — but it is the payload
/// saying less than it knows, and a key nothing reads invites the next reader to assume
/// it is drawn. [Routine.logs] now follows the wire, and [Routine.isEmpty] with it.
///
/// The kinds already drawn from their own fields are **not** drawn twice:
/// `logs_summary` counts every `manual_entry` kind including `meditation` and `fasting`,
/// which have dedicated blocks above. [Routine.otherLogs] is the rest.
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

/// One kind of manual entry, rolled up for the day: how many, and how much.
@immutable
class LogTally {
  /// A day's total for one kind.
  const LogTally({required this.kind, required this.count, required this.total});

  /// The entry kind as the server names it — `caffeine`, `water`, `mood`, …
  final String kind;

  /// How many entries of this kind were logged.
  final int count;

  /// Their summed `amount`. Zero for a kind that carries no amount (`mood`,
  /// `symptom`, `habit`), which is why [count] is the figure that decides whether
  /// there is anything to say.
  final double total;
}

/// Today's routine: sessions, meditation, an open fast, and the day's other logs.
@immutable
class Routine {
  /// Builds a day. Prefer [Routine.fromJson].
  const Routine({
    required this.workouts,
    required this.meditationCount,
    required this.meditationMinutes,
    required this.openFast,
    this.logs = const <LogTally>[],
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
      logs: _tallies(json['logs_summary']),
    );
  }

  /// Parses `logs_summary` — `{kind: {count, total}}` — in the server's own key order.
  ///
  /// A kind with a zero or missing count is dropped rather than kept at zero: the roll-up
  /// is a GROUP BY, so a zero cannot arrive from the server, and carrying one would put a
  /// row on screen for something the owner did not log.
  static List<LogTally> _tallies(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return const <LogTally>[];
    }
    final out = <LogTally>[];
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map<String, Object?>) {
        continue;
      }
      final count = (value['count'] as num?)?.toInt() ?? 0;
      if (count <= 0) {
        continue;
      }
      out.add(
        LogTally(
          kind: entry.key,
          count: count,
          total: (value['total'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return out;
  }

  /// Today's sessions, newest first.
  final List<RoutineEvent> workouts;

  /// How many meditation entries were logged today.
  final int meditationCount;

  /// Their total minutes.
  final int meditationMinutes;

  /// A fast still running, or null.
  final OpenFast? openFast;

  /// Every manual-entry kind the day carried, rolled up. `routine.logs_summary`.
  final List<LogTally> logs;

  /// The logged kinds that do NOT already have a block of their own above.
  ///
  /// `logs_summary` counts every `manual_entry` kind, so `meditation` is in it and so is
  /// `fasting` — both already drawn from their own fields. Printing them from here as
  /// well would be two renderings of one entry, disagreeing the moment the two shapes
  /// diverge (the fast's block is about an OPEN one; the tally counts every fast of the
  /// day). One definition per thing on screen.
  Iterable<LogTally> get otherLogs =>
      logs.where((tally) => !_ownBlock.contains(tally.kind));

  static const Set<String> _ownBlock = <String>{'meditation', 'fasting'};

  /// Whether there is anything at all to say. **A day with nothing logged draws
  /// nothing** — no card, no heading, no "nothing yet" placeholder.
  ///
  /// It follows the WIRE: a day whose only entry was caffeine used to render no panel
  /// while the payload reported that entry (audit C6).
  bool get isEmpty =>
      workouts.isEmpty &&
      meditationCount == 0 &&
      openFast == null &&
      otherLogs.isEmpty;
}
