/// Recovery (0–100), readiness, and the per-factor breakdown that must ship with it.
///
/// `docs/APP_DESIGN.md` §1 lists Recovery 0–100 as one of five *approved*
/// composite scores — approved specifically because it "always renders its
/// per-factor breakdown". [factors] and [weights] are therefore required fields:
/// a `RecoveryScore` that could exist without its components would let a screen
/// show the bare number, which `feedback_no_composite_score` forbids.
library;

import 'package:meta/meta.dart';

/// One contributing signal's sub-score, and how much of the total it carries.
@immutable
class RecoveryFactor {
  /// A named factor.
  const RecoveryFactor({required this.name, required this.subScore, required this.weight});

  /// Signal id: `hrv`, `rhr`, `rr`, `sleep`.
  final String name;

  /// This factor's own 0–100 score. Null when the signal was missing entirely,
  /// which is a real state — a night without HRV still produces a recovery number
  /// from the remaining factors, and the breakdown must show which one is absent
  /// rather than drawing a zero bar.
  final int? subScore;

  /// Its share of the total, 0–1.
  final double? weight;
}

/// The day's recovery, readiness, and the guidance line derived from them.
@immutable
class RecoveryScore {
  /// Builds a score. Prefer [RecoveryScore.maybe].
  const RecoveryScore({
    required this.recovery,
    required this.readiness,
    required this.band,
    required this.guidance,
    required this.factors,
    required this.noteId,
    required this.date,
  });

  /// Parses the payload, or null when there is no score for today.
  static RecoveryScore? maybe(Map<String, Object?> json) {
    final recovery = (json['recovery'] as num?)?.toInt();
    if (recovery == null) {
      return null;
    }
    return RecoveryScore(
      recovery: recovery,
      readiness: (json['readiness'] as num?)?.toInt(),
      band: json['band'] as String?,
      guidance: json['guidance'] as String?,
      factors: _factors(json['factors'], json['weights']),
      noteId: json['note_id'] as String?,
      date: json['date'] as String?,
    );
  }

  /// 0–100, evidence-weighted against the owner's own 42-day baseline.
  final int recovery;

  /// Today's remaining capacity — recovery decayed by strain already spent.
  final int? readiness;

  /// `high` (>=67) · `moderate` (>=34) · `low`. Sets the day's intensity ceiling.
  final String? band;

  /// The deterministic guidance sentence. Rule-based, not LLM, therefore free on
  /// every tier (`docs/APP_DESIGN.md` §4) — and rendered verbatim, because an
  /// active illness flag overrides its text and the app must not re-word that.
  final String? guidance;

  /// The per-factor breakdown. Never empty when a score exists; rendering the
  /// number without it is the composite-score rule broken.
  final List<RecoveryFactor> factors;

  /// The research note licensing the score.
  final String? noteId;

  /// The day this score is a claim about.
  final String? date;

  static List<RecoveryFactor> _factors(Object? rawFactors, Object? rawWeights) {
    if (rawFactors is! Map<String, Object?>) {
      return const [];
    }
    final weights = rawWeights is Map<String, Object?> ? rawWeights : const <String, Object?>{};
    return [
      for (final entry in rawFactors.entries)
        RecoveryFactor(
          name: entry.key,
          subScore: entry.value is Map<String, Object?>
              ? ((entry.value! as Map<String, Object?>)['sub'] as num?)?.toInt()
              : null,
          weight: (weights[entry.key] as num?)?.toDouble(),
        ),
    ];
  }
}
