/// Today's action — the one place on this screen with an evidence GRADE on it.
///
/// ## Where the grade comes from, and why nothing else on Today has one
///
/// `recommendations[].evidence_grade` is an integer on the server's own
/// `GRADE_RANK` scale (`core/knowledge.py`): 3 = Established, 2 = Probable, and
/// the `recommendation` table's CHECK constraint admits only those two. It is
/// not the model's self-declared number — `jobs/recs.py::_provable_grade`
/// replaces the declaration with **the weakest grade among the notes the rec
/// actually cites**, so what arrives here is a claim the manifest backs.
///
/// That is why [gradeLabel] is allowed to exist, and why nothing else on this
/// screen gets one. The other blocks carry `research_notes` — citation ids
/// without grades — and inventing "Established" from an id would rebuild the
/// exact `evidence_grade`-vs-`grade` split that once published a `Myth` note as
/// fact (#83). Ids render as citations; grades render only where one was sent.
library;

import 'package:meta/meta.dart';

/// One dated, cited action.
@immutable
class Recommendation {
  /// Built by [Recommendation.fromJson].
  const Recommendation({
    required this.id,
    required this.action,
    required this.rationale,
    required this.expectedEffect,
    required this.category,
    required this.evidenceGrade,
    required this.researchNoteIds,
    required this.signalSource,
    required this.adopted,
  });

  /// Parses one entry of `recommendations`.
  factory Recommendation.fromJson(Map<String, Object?> json) {
    return Recommendation(
      id: (json['id'] as num?)?.toInt(),
      action: json['action']! as String,
      rationale: json['rationale'] as String?,
      expectedEffect: json['expected_effect'] as String?,
      category: json['category'] as String?,
      evidenceGrade: (json['evidence_grade'] as num?)?.toInt(),
      researchNoteIds: [
        for (final entry in (json['research_note_ids'] as List? ?? const []))
          if (entry is String) entry,
      ],
      signalSource: json['signal_source'] as String?,
      adopted: json['adopted'] as bool?,
    );
  }

  /// The server's row id.
  final int? id;

  /// What to do, in one sentence.
  final String action;

  /// Why — the personalised half, grade-calibrated at the choke point.
  final String? rationale;

  /// What it should change.
  final String? expectedEffect;

  /// `sleep` · `activity` · …
  final String? category;

  /// The PROVEN grade on `GRADE_RANK`'s scale. See the library docstring.
  final int? evidenceGrade;

  /// The notes this rests on. Rendered as citations.
  final List<String> researchNoteIds;

  /// Which metric raised it.
  final String? signalSource;

  /// Whether the owner has taken it on, when the server tracks that.
  final bool? adopted;

  /// The grade as its own word, or null when none was sent.
  ///
  /// Only the two shippable ranks are named. An unexpected value returns null
  /// rather than a guess: a rank we do not recognise is one whose framing we
  /// cannot calibrate, and a wrong confidence label is worse than none.
  String? get gradeLabel => switch (evidenceGrade) {
    3 => 'Established',
    2 => 'Probable',
    _ => null,
  };
}
