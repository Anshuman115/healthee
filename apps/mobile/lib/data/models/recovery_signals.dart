/// The recovery **signal ladder** — the payload behind the signature chart.
///
/// `recovery.signals[]`, each `{name, value, baseline, z, direction, unit,
/// research_note_id}`. Brief §5.1 makes the case for why this replaces the ring
/// everyone else draws: a 72 tells you nothing, and "HRV is 1.4σ below your
/// normal, everything else is at baseline" tells you what to do.
///
/// Two things the model keeps structural.
///
/// **[z] may be null and that is not zero.** A signal with no baseline yet has
/// no position on the ladder, and drawing it at the centre line would assert it
/// is exactly normal. It renders as a row with no marker instead.
///
/// **[direction] comes from the server, always.** Which side of the baseline is
/// favourable is a research question — a low resting heart rate is good, a low
/// HRV is not — and re-deriving it from the sign of `z` in the UI would put that
/// judgement in the one place with no access to the evidence.
library;

import 'package:meta/meta.dart';

/// One signal, positioned against its own baseline.
@immutable
class RecoverySignal {
  /// A named signal with its personal comparison.
  const RecoverySignal({
    required this.name,
    required this.value,
    required this.baseline,
    required this.z,
    required this.direction,
    required this.unit,
    required this.researchNoteId,
  });

  /// Parses one entry of `recovery.signals`.
  factory RecoverySignal.fromJson(Map<String, Object?> json) {
    return RecoverySignal(
      name: json['name']! as String,
      value: (json['value'] as num?)?.toDouble(),
      baseline: (json['baseline'] as num?)?.toDouble(),
      z: (json['z'] as num?)?.toDouble(),
      direction: json['direction'] as String?,
      unit: json['unit'] as String?,
      researchNoteId: json['research_note_id'] as String?,
    );
  }

  /// Owner-facing name — "Sleep duration", "HRV".
  final String name;

  /// Today's reading.
  final double? value;

  /// The owner's own normal for this signal. **Not a population norm** — brief
  /// §5.2 is explicit that population norms are irrelevant here.
  final double? baseline;

  /// Standard scores from [baseline]. Null when there is no baseline yet.
  final double? z;

  /// `favorable` · `unfavorable` · `neutral`, as the server judged it.
  final String? direction;

  /// Unit of [value] and [baseline].
  final String? unit;

  /// The note licensing this signal. Tappable, per brief §5.1.
  final String? researchNoteId;

  /// Whether this row can be drawn against the centre line at all.
  bool get hasPosition => z != null;
}

/// The whole ladder, plus the server's one-line reading of it.
@immutable
class RecoverySignals {
  /// Built by [RecoverySignals.maybe].
  const RecoverySignals({
    required this.summary,
    required this.signals,
    required this.favorable,
    required this.unfavorable,
    required this.neutral,
  });

  /// Parses `recovery`, or null when there are no signals to draw.
  ///
  /// Null on an empty list rather than an empty ladder: a chart with no rows is
  /// a frame around nothing, and the honest render for it is a refusal.
  static RecoverySignals? maybe(Map<String, Object?> json) {
    final signals = [
      for (final entry in (json['signals'] as List? ?? const []))
        if (entry is Map<String, Object?>) RecoverySignal.fromJson(entry),
    ];
    if (signals.isEmpty) {
      return null;
    }
    return RecoverySignals(
      summary: json['summary'] as String?,
      signals: signals,
      favorable: (json['favorable'] as num?)?.toInt() ?? 0,
      unfavorable: (json['unfavorable'] as num?)?.toInt() ?? 0,
      neutral: (json['neutral'] as num?)?.toInt() ?? 0,
    );
  }

  /// "Recovery signals lean favorable" — the server's sentence, rendered
  /// verbatim. It is a calibrated statement and re-wording it in the UI is how
  /// calibration gets lost.
  final String? summary;

  /// One row per signal, in server order.
  final List<RecoverySignal> signals;

  /// How many signals sit on the favourable side.
  final int favorable;

  /// How many sit on the unfavourable side.
  final int unfavorable;

  /// How many are at baseline.
  final int neutral;
}
