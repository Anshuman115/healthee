/// Biological age — the payload that exercises all four honesty states at once.
///
/// It is the richest example in the contract snapshot and the reason the union
/// has four cases rather than three:
///
///   * a **value** (34.3 years) — so it is not withheld;
///   * **`caveats`** naming which way the fitness and sleep terms lean — so it is
///     `Caveated`, not `Present`;
///   * an **`excluded`** entry saying sleep regularity cannot be converted into
///     years at all, *alongside* that value — the case that proves an exclusion
///     narrows a number rather than suppressing it;
///   * and a **`withheld`** slot that fires when the inputs cannot carry it.
///
/// The per-lever [contributions] are mandatory for the same reason recovery's
/// factors are: `docs/APP_DESIGN.md` §1 approves biological age as a composite
/// only when it "always renders its per-factor breakdown".
library;

import 'package:meta/meta.dart';

/// One lever's contribution, in years.
@immutable
class AgeContribution {
  /// A named term of the estimate.
  const AgeContribution({
    required this.term,
    required this.deltaYears,
    required this.value,
    required this.target,
    required this.unit,
    required this.method,
  });

  /// Parses one entry of `contributions`.
  factory AgeContribution.fromJson(Map<String, Object?> json) {
    return AgeContribution(
      term: json['term']! as String,
      deltaYears: (json['delta_years'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      target: (json['target'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      method: json['method'] as String?,
    );
  }

  /// Which lever: `fitness`, `sleep`, …
  final String term;

  /// Years added (positive) or removed (negative) by this lever.
  final double? deltaYears;

  /// The owner's own measured value for the lever.
  final double? value;

  /// The reference this lever is scored against.
  final double? target;

  /// Unit of [value] and [target].
  final String? unit;

  /// The instrument behind [value], when it had one.
  final String? method;
}

/// A motivational biological-age estimate with its levers.
@immutable
class BiologicalAge {
  /// Builds an estimate. Prefer [BiologicalAge.maybe].
  const BiologicalAge({
    required this.biologicalAge,
    required this.chronologicalAge,
    required this.deltaYears,
    required this.contributions,
    required this.disclaimer,
    required this.researchNotes,
  });

  /// Parses the payload, or null when there is no estimate.
  static BiologicalAge? maybe(Map<String, Object?> json) {
    final years = (json['biological_age'] as num?)?.toDouble();
    if (years == null) {
      return null;
    }
    return BiologicalAge(
      biologicalAge: years,
      chronologicalAge: (json['chronological_age'] as num?)?.toDouble(),
      deltaYears: (json['delta_years'] as num?)?.toDouble(),
      contributions: [
        for (final entry in (json['contributions'] as List? ?? const []))
          if (entry is Map<String, Object?>) AgeContribution.fromJson(entry),
      ],
      disclaimer: json['disclaimer'] as String?,
      researchNotes: [
        for (final entry in (json['research_notes'] as List? ?? const []))
          if (entry is String) entry,
      ],
    );
  }

  /// The estimate, in years.
  final double biologicalAge;

  /// The owner's actual age, for the comparison the number exists to make.
  final double? chronologicalAge;

  /// [biologicalAge] minus [chronologicalAge].
  final double? deltaYears;

  /// The per-lever breakdown. Rendered beside the number, always.
  final List<AgeContribution> contributions;

  /// "Motivational estimate from population data — not a clinical or diagnostic
  /// age." Server-supplied and rendered verbatim: it is a safety statement, and
  /// re-wording a safety statement in the UI layer is how it gets softened.
  final String? disclaimer;

  /// The notes licensing the estimate.
  final List<String> researchNotes;
}
