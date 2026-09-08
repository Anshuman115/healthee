/// The illness flag — deterministic, safety-critical, and not AI.
///
/// Brief §4.1 ranks it above everything else on Today, and §2 reserves the
/// product's one red for it alone. Both are properties of what it is: a
/// rule-based signal from respiratory rate and skin temperature moving together
/// against the owner's own baseline, with research notes behind it.
///
/// [framing] is rendered **verbatim**. It is the calibrated sentence — it says
/// "possible early signal" and "consider", not "you are ill" — and re-wording a
/// safety statement in the UI layer is exactly how one gets softened or
/// sharpened by somebody with no access to the evidence.
library;

import 'package:meta/meta.dart';

/// A possible early illness signal, with the deltas behind it.
@immutable
class IllnessFlag {
  /// Built by [IllnessFlag.maybe].
  const IllnessFlag({
    required this.date,
    required this.severity,
    required this.sustained,
    required this.framing,
    required this.respiratoryRateDeltaBpm,
    required this.skinTempDeltaC,
    required this.researchNoteIds,
  });

  /// Parses `illness_flag`, or null when nothing is flagged.
  ///
  /// [framing] is required rather than optional: a flag with no sentence has
  /// nothing honest to render, and a banner reading "moderate" at somebody is a
  /// severity with no claim attached.
  static IllnessFlag? maybe(Map<String, Object?> json) {
    final framing = json['framing'];
    if (framing is! String || framing.isEmpty) {
      return null;
    }
    return IllnessFlag(
      date: json['date'] as String?,
      severity: json['severity'] as String?,
      sustained: json['sustained'] as bool? ?? false,
      framing: framing,
      respiratoryRateDeltaBpm: (json['rr_delta_bpm'] as num?)?.toDouble(),
      skinTempDeltaC: (json['temp_delta_c'] as num?)?.toDouble(),
      researchNoteIds: [
        for (final entry in (json['research_note_ids'] as List? ?? const []))
          if (entry is String) entry,
      ],
    );
  }

  /// The day this is about.
  final String? date;

  /// `moderate` · `high`, as the rule graded it. **Not drawn anywhere.**
  ///
  /// Two corrections, both from the audit's D8. The vocabulary used to read
  /// `mild · moderate · high` and `mild` cannot occur: `schema.sql` is
  /// `CHECK (severity IN ('moderate', 'high'))` and `derive/illness.py` says mild is
  /// never written. A docstring naming a state the schema forbids is the same species
  /// as a comment naming a test that does not exist.
  ///
  /// And it reaches no surface: `illness_banner.dart` has one visual treatment for both
  /// grades, deliberately — the banner spends this product's only red and a two-tier red
  /// would be a severity scale nothing in the corpus grades. It is parsed because a log
  /// line and the ⓘ want it, not because a screen reads it.
  final String? severity;

  /// Whether the signal has held across more than one night. A single night is
  /// a reading; several is a pattern, and the copy must not conflate them.
  final bool sustained;

  /// The server's calibrated sentence. Rendered as sent.
  final String framing;

  /// Respiratory rate above the owner's own baseline, breaths per minute.
  final double? respiratoryRateDeltaBpm;

  /// Skin temperature above baseline, °C.
  final double? skinTempDeltaC;

  /// The notes behind the rule.
  final List<String> researchNoteIds;
}
