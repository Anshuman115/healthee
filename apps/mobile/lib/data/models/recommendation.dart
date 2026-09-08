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

import 'package:healthee/data/honesty/citations.dart';
import 'package:meta/meta.dart';

/// One dated, cited action.
@immutable
class Recommendation {
  /// Built by [Recommendation.fromJson].
  const Recommendation({
    required this.id,
    required this.date,
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
      date: json['date'] as String?,
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

  /// The day this action was WRITTEN FOR, `YYYY-MM-DD`, as the server sent it.
  ///
  /// This class calls itself "one dated, cited action" and had no date. The
  /// server has always put one on every row (`read/recommendations.py`), and
  /// this parser dropped it — while `read/today.py::_recommendations_for`
  /// reaches back **two days** for the newest set at or before the day being
  /// served. So a Monday action was drawn on Wednesday under a heading saying
  /// "today", with nothing on screen able to say otherwise. That is the
  /// stale-as-current lie (`docs/HOW_WE_VERIFY.md` section 3) in prose instead of in a
  /// number, and this field is what lets `actions_section.dart` name the day
  /// instead of implying one.
  ///
  /// Null when the server sent none, and null is never filled in from the day
  /// being viewed — an undated row is one whose day we do not know, which is a
  /// different statement from "it is this day's".
  final String? date;

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

  /// Everything backing this recommendation, as one bundle for its ⓘ.
  ///
  /// All three model-written fields, plus [researchNoteIds]. They are three
  /// sentences about ONE suggestion sharing one set of notes, so they ground
  /// together — the rule `data/honesty/citations.dart` states for
  /// [groundingOfAll].
  ///
  /// It lives on the model rather than beside a card because four surfaces draw
  /// this object (Today's action row, the Actions suggestion card, the dated
  /// history card, and the shared recommendation entry) and they must not be
  /// able to show a reader different sources for the same suggestion. A helper
  /// in any one of their files would also be an import reaching sideways
  /// between features, which Standards section 1 forbids.
  Grounding get grounding => groundingOfAll(<String?>[
    action,
    rationale,
    expectedEffect,
  ], alsoCites: researchNoteIds);
}
