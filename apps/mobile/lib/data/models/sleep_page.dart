/// `GET /api/sleep` — everything the Sleep tab is drawn from.
///
/// The endpoint returns `{cutoffs, findings, naps, nights, research_notes}` and
/// the port parsed two of the five. That was right at the time — legacy's screen
/// draws none of the other three, and a model field with no reader is the shape
/// dead code takes in a data layer — and it is wrong now, because the owner
/// opened surfacing what the new API gives.
///
/// All five are parsed. Each has a reader:
///
///   * **`cutoffs`** replaces four thresholds that were hardcoded in
///     `sleep_health_card.dart` — a second definition of science that lives on
///     the server, which is exactly what CLAUDE.md's one-definition rule is
///     about. It is a constant dict server-side, so it is never absent; the
///     card still tolerates absence rather than asserting the shape.
///   * **`research_notes`** are the four notes licensing those cutoffs. They
///     were the one part of the Sleep tab with no citation at all.
///   * **`findings`** are sleep-scoped correlations from the same shape
///     `/api/today`'s `top_findings` uses, and were reaching no screen.
///
/// **`naps[].stages` used to parse to nothing, and that was a server bug rather
/// than a gap here**: `read/sleep_page.py` shipped the raw JSONB hypnogram
/// (`[[startMs, endMs, typeCode]]`) under the key a *night* uses for per-stage
/// minute TOTALS, so `NapStage.fromJson` never saw a map and every nap's stage
/// list was empty on every payload. It was reported rather than worked around,
/// because reading that array here would have meant re-implementing the strap's
/// stage-code mapping in the UI layer — a second definition of what a stage is.
///
/// The server shapes a nap like a night now, so this model does too: `stages` is
/// [StageMinutes] and the hypnogram is [SleepStageSpan]s under `timeline`, both
/// of them the night's own types. `NapStage` is gone with the bug that created
/// it — it existed only to read a shape that turned out to be the defect, and
/// keeping a nap-only span type beside `SleepStageSpan` would be the second
/// definition the old comment was refusing.
library;

import 'package:healthee/data/models/finding.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:meta/meta.dart';

/// One daytime sleep the strap tagged `kind='nap'`.
@immutable
class SleepNap {
  /// Builds a nap.
  const SleepNap({
    required this.date,
    required this.start,
    required this.end,
    required this.durationMin,
    required this.midpointLocal,
    required this.stages,
    required this.timeline,
  });

  /// Parses one entry of `naps[]` — the same two stage fields a night carries.
  factory SleepNap.fromJson(Map<String, Object?> json) {
    return SleepNap(
      date: json['date'] as String?,
      start: _instant(json['start_iso']),
      end: _instant(json['end_iso']),
      durationMin: (json['duration_min'] as num?)?.toDouble(),
      midpointLocal: json['midpoint_local'] as String?,
      stages: StageMinutes.fromJson(
        json['stages'] is Map<String, Object?>
            ? json['stages']! as Map<String, Object?>
            : const <String, Object?>{},
      ),
      timeline: <SleepStageSpan>[
        for (final span
            in (json['stage_timeline'] as List<Object?>? ?? const <Object?>[]))
          if (span is Map<String, Object?>) SleepStageSpan.fromJson(span),
      ],
    );
  }

  /// The owner-local date the nap started on.
  final String? date;

  /// When it started.
  final DateTime? start;

  /// When it ended.
  final DateTime? end;

  /// How long it lasted, minutes.
  final double? durationMin;

  /// Its midpoint as the server formatted it, `HH:MM`.
  final String? midpointLocal;

  /// Its per-stage minute totals. Zeroed rather than absent when the strap
  /// staged nothing, exactly as a night's are — [StageMinutes.isEmpty] is how
  /// "not staged" is asked, never a missing field.
  final StageMinutes stages;

  /// Its hypnogram, in order. Often empty on a nap even when [stages] is not:
  /// the strap frequently sends a summary without the spans behind it, and the
  /// two are independent facts.
  final List<SleepStageSpan> timeline;
}

/// The published thresholds the four sleep-health checks are scored against.
///
/// **The server's `read/sleep_common.py::SLEEP_CUTOFFS`, carried rather than
/// copied.** They were four string literals in `sleep_health_card.dart`, which
/// made the app a second place the science lived: change `efficiency_min` on the
/// server and the card would keep printing `≥ 85%` beside a check scored against
/// something else, and nothing would fail.
///
/// Every field is nullable. The server has never omitted one — it is a module
/// constant — but a card that asserts a shape it does not control is a crash
/// waiting on a deployment, and the honest fallback is the card's own words.
@immutable
class SleepCutoffs {
  /// Builds a cutoff set.
  const SleepCutoffs({
    required this.durationHours,
    required this.efficiencyMin,
    required this.timingHourBand,
    required this.sriMin,
  });

  /// Parses `cutoffs`, or null when the payload carried none.
  static SleepCutoffs? maybe(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    List<double>? pair(Object? value) {
      if (value is! List || value.length != 2) {
        return null;
      }
      final bounds = <double>[
        for (final entry in value)
          if (entry is num) entry.toDouble(),
      ];
      // A half-parsed pair is worse than none: it would render a band with one
      // end invented. All or nothing.
      return bounds.length == 2 ? bounds : null;
    }

    return SleepCutoffs(
      durationHours: pair(raw['duration_hours']),
      efficiencyMin: (raw['efficiency_min'] as num?)?.toDouble(),
      timingHourBand: pair(raw['timing_hour_band']),
      sriMin: (raw['sri_min'] as num?)?.toDouble(),
    );
  }

  /// `[7.0, 9.0]` — the NSF 2015 band, in hours.
  final List<double>? durationHours;

  /// `0.85` — a FRACTION, not a percentage. The card multiplies.
  final double? efficiencyMin;

  /// `[2, 4]` — the sleep-midpoint band, in local hours.
  final List<double>? timingHourBand;

  /// `70.0` — the Sleep Regularity Index floor.
  final double? sriMin;
}

/// The whole `/api/sleep` payload, typed.
@immutable
class SleepPage {
  /// Builds a page.
  const SleepPage({
    required this.nights,
    required this.naps,
    required this.cutoffs,
    required this.findings,
    required this.researchNotes,
  });

  /// Parses the payload. Nights arrive newest first and stay that way — every
  /// chart on the screen reverses the slice it wants, exactly as legacy does.
  factory SleepPage.fromJson(Map<String, Object?> json) => SleepPage(
    nights: <SleepNight>[
      for (final night
          in (json['nights'] as List<Object?>? ?? const <Object?>[]))
        if (night is Map<String, Object?>) SleepNight.fromJson(night),
    ],
    naps: <SleepNap>[
      for (final nap in (json['naps'] as List<Object?>? ?? const <Object?>[]))
        if (nap is Map<String, Object?>) SleepNap.fromJson(nap),
    ],
    cutoffs: SleepCutoffs.maybe(json['cutoffs']),
    findings: <Finding>[
      for (final entry
          in (json['findings'] as List<Object?>? ?? const <Object?>[]))
        if (entry is Map<String, Object?>) Finding.fromJson(entry),
    ],
    researchNotes: <String>[
      for (final id
          in (json['research_notes'] as List<Object?>? ?? const <Object?>[]))
        if (id is String) id,
    ],
  );

  /// Newest first.
  final List<SleepNight> nights;

  /// Newest first.
  final List<SleepNap> naps;

  /// The thresholds the four checks are scored against, or null.
  final SleepCutoffs? cutoffs;

  /// Sleep-scoped correlations from this owner's own history. Often empty, and
  /// an empty list renders nothing at all — no heading, no zero-state.
  final List<Finding> findings;

  /// The corpus notes licensing the four sleep-health cutoffs.
  final List<String> researchNotes;

  /// The most recent night, or null when the owner has none.
  SleepNight? get latest => nights.isEmpty ? null : nights.first;
}

DateTime? _instant(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
