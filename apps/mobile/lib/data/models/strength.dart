/// The week's strength training against the 30–60 minute band.
///
/// `read/fitness.py::strength_payload`, and **legacy referenced it in one file**
/// — effectively never surfaced. It is the second half of the activity
/// guideline the MVPA card already draws the first half of: minutes of
/// moderate-to-vigorous work, *and* muscle-strengthening on two or more days.
/// [[strength_training_mortality]] (Momma 2022) is the note the server attaches.
///
/// ## Zero is a reading here, and absent is not
///
/// `week_min: 0` with `sessions: 0` is a real answer — the owner did no strength
/// work this week, against a target that exists. That renders. A payload with no
/// `strength` block at all renders **nothing**, because there is then no target
/// to be at zero against. [Strength.maybe] draws that line: it returns null only
/// when the block is missing or carries no target.
library;

import 'package:meta/meta.dart';

/// Weekly strength minutes, sessions and target band.
@immutable
class Strength {
  /// Builds a week. Prefer [Strength.maybe].
  const Strength({
    required this.weekMin,
    required this.sessions,
    required this.targetLowMin,
    required this.targetHighMin,
    required this.types,
    required this.weekStartIso,
    required this.researchNote,
  });

  /// Parses `strength`, or null when the server sent no block.
  static Strength? maybe(Map<String, Object?> json) {
    final low = (json['target_low'] as num?)?.toInt();
    final high = (json['target_high'] as num?)?.toInt();
    if (low == null || high == null) {
      return null;
    }
    return Strength(
      weekMin: (json['week_min'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      targetLowMin: low,
      targetHighMin: high,
      types: [
        for (final entry in (json['types'] as List? ?? const []))
          if (entry is String) entry,
      ],
      weekStartIso: json['week_start_iso'] as String?,
      researchNote: json['research_note'] as String?,
    );
  }

  /// Minutes of strength work since Monday.
  final int weekMin;

  /// How many sessions those minutes came from.
  final int sessions;

  /// The bottom of the band the note supports.
  final int targetLowMin;

  /// The top of it. Above this the evidence stops improving, which is why the
  /// target is a band and not a floor.
  final int targetHighMin;

  /// Which kinds of session counted — `strength`, `yoga`.
  final List<String> types;

  /// The Monday this week began, `YYYY-MM-DD`.
  final String? weekStartIso;

  /// The note licensing the band.
  final String? researchNote;
}
