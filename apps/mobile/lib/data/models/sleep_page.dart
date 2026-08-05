/// `GET /api/sleep` — the nights and the naps the Sleep tab is drawn from.
///
/// The endpoint also returns `cutoffs`, `findings` and `research_notes`. **They
/// are not parsed here**, because legacy's Sleep screen draws none of them and
/// this is a verbatim port: a model field with no reader is a promise that some
/// future screen will keep, which is the shape dead code takes in a data layer.
/// The findings feed `features/insights/` off `/api/today` already.
library;

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
  });

  /// Parses one entry of `naps[]`.
  factory SleepNap.fromJson(Map<String, Object?> json) {
    return SleepNap(
      date: json['date'] as String?,
      start: _instant(json['start_iso']),
      end: _instant(json['end_iso']),
      durationMin: (json['duration_min'] as num?)?.toDouble(),
      midpointLocal: json['midpoint_local'] as String?,
      stages: <NapStage>[
        for (final span in (json['stages'] as List<Object?>? ?? const <Object?>[]))
          if (span is Map<String, Object?>) NapStage.fromJson(span),
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

  /// Its staged spans, in order. Often empty — a nap is short and the strap
  /// frequently stages nothing.
  final List<NapStage> stages;
}

/// One staged span inside a nap. Narrower than `SleepStageSpan` on purpose: the
/// nap bar is drawn from durations alone and never from offsets.
@immutable
class NapStage {
  /// Builds a nap span.
  const NapStage({required this.stage, required this.durationMin});

  /// Parses one entry of `naps[].stages`.
  factory NapStage.fromJson(Map<String, Object?> json) => NapStage(
    stage: json['stage'] as String? ?? '',
    durationMin: (json['duration_min'] as num?)?.toDouble() ?? 0,
  );

  /// `light` · `deep` · `rem` · `awake`, as the strap wrote it.
  final String stage;

  /// How long the span lasted.
  final double durationMin;
}

/// The whole `/api/sleep` payload, typed.
@immutable
class SleepPage {
  /// Builds a page.
  const SleepPage({required this.nights, required this.naps});

  /// Parses the payload. Nights arrive newest first and stay that way — every
  /// chart on the screen reverses the slice it wants, exactly as legacy does.
  factory SleepPage.fromJson(Map<String, Object?> json) => SleepPage(
    nights: <SleepNight>[
      for (final night in (json['nights'] as List<Object?>? ?? const <Object?>[]))
        if (night is Map<String, Object?>) SleepNight.fromJson(night),
    ],
    naps: <SleepNap>[
      for (final nap in (json['naps'] as List<Object?>? ?? const <Object?>[]))
        if (nap is Map<String, Object?>) SleepNap.fromJson(nap),
    ],
  );

  /// Newest first.
  final List<SleepNight> nights;

  /// Newest first.
  final List<SleepNap> naps;

  /// The most recent night, or null when the owner has none.
  SleepNight? get latest => nights.isEmpty ? null : nights.first;
}

DateTime? _instant(Object? raw) =>
    raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
