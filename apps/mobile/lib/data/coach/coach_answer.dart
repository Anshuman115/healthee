/// `POST /api/coach`, typed — one answer, with everything that qualifies it.
///
/// The router returns eight fields and three of them are the honesty contract
/// rather than metadata, so none of them is optional to render:
///
/// ```text
///   reply              the prose, with inline [note_id] markers left in
///   citations          the notes it rests on
///   grade_floor        the WEAKEST grade among them (INTELLIGENCE §3)
///   validated          false = the honest fallback shipped, not the answer asked for
///   refused            classified out of scope before any model ran
/// ```
///
/// `grade_floor` was computed on every answer and dropped on the wire once (#84),
/// so the flagship surface shipped citations with no statement of how firm they
/// are. `null` there means *nothing gradeable was cited*, which is not the same as
/// a weak grade, and this model keeps the two apart rather than defaulting one to
/// the other.
///
/// ## `refused` and `validated` are not errors
///
/// Both are the product working. A refusal is the coach declining a question it
/// may not answer; an unvalidated reply is the blocking validator having rejected
/// the model's answer and the honest fallback having shipped instead. The server
/// **refunds the metered question** in both cases (`routers/coach.py`), so the
/// app must not count them as spent either — `features/coach/coach_controller.dart`
/// re-reads the meter from the server rather than decrementing its own copy, for
/// exactly this reason.
library;

import 'package:meta/meta.dart';

/// One coach turn's answer.
@immutable
class CoachAnswer {
  /// Built by [CoachAnswer.fromJson].
  const CoachAnswer({
    required this.reply,
    required this.citations,
    required this.gradeFloor,
    required this.refused,
    required this.validated,
  });

  /// Parses the router's body.
  factory CoachAnswer.fromJson(Map<String, Object?> json) {
    return CoachAnswer(
      reply: json['reply'] as String? ?? '',
      citations: <String>[
        for (final entry in (json['citations'] as List? ?? const []))
          if (entry is String) entry,
      ],
      gradeFloor: json['grade_floor'] as String?,
      refused: json['refused'] == true,
      validated: json['validated'] != false,
    );
  }

  /// The answer, raw. Rendered through `GroundedProse`, never printed.
  final String reply;

  /// The notes cited, as ids.
  final List<String> citations;

  /// The weakest grade among them, or null when nothing gradeable was cited.
  final String? gradeFloor;

  /// The question was classified out of scope before any model ran.
  final bool refused;

  /// False when the blocking validator rejected the answer and the fallback
  /// shipped. The reply is still honest; it is just not what was asked.
  final bool validated;

  /// Whether the server refunded this turn's metered question.
  ///
  /// Mirrors `routers/coach.py`'s two refund branches exactly. It is here so the
  /// app can *say* a question was not spent, which is the other half of "a spend
  /// must never be silent" — a silent non-spend is a smaller lie, but it is the
  /// same kind.
  bool get wasRefunded => refused || !validated;
}
