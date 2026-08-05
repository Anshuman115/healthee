/// `GET /api/sleep/insight` — the grounded analysis, and whether it was allowed.
///
/// `insights/surfaces.py::_generate` returns the text with `citations`,
/// `grade_floor`, `refused` and `validated` beside it. Three of those four are
/// honesty fields and all three reach the screen:
///
/// ```text
///   citations    the corpus ids backing the text — rendered as SOURCE NAMES
///   grade_floor  the weakest grade among them — the qualification on the whole
///   refused      the pipeline declined; there is no analysis and saying so is
///                different from saying there is not enough data yet
/// ```
///
/// `validated` is deliberately not surfaced as its own line: the server only
/// **caches** validated output, and an unvalidated answer still carries its
/// citations and its grade. Adding a fourth state to the card would be a claim
/// about the pipeline the payload does not make.
library;

import 'package:meta/meta.dart';

/// The grounded sleep analysis, or the reason there is not one.
@immutable
class SleepInsight {
  /// Builds an analysis.
  const SleepInsight({
    required this.text,
    required this.citations,
    required this.gradeFloor,
    required this.refused,
    this.locked = false,
  });

  /// The plan does not include AI analysis. Not a failure — see
  /// `data/sleep_repository.dart`.
  const SleepInsight.locked()
    : text = '',
      citations = const <String>[],
      gradeFloor = null,
      refused = false,
      locked = true;

  /// Parses the payload.
  factory SleepInsight.fromJson(Map<String, Object?> json) => SleepInsight(
    text: (json['insight'] as String?)?.trim() ?? '',
    citations: <String>[
      for (final id in (json['citations'] as List<Object?>? ?? const <Object?>[]))
        if (id is String && id.isNotEmpty) id,
    ],
    gradeFloor: json['grade_floor'] as String?,
    refused: json['refused'] == true,
  );

  /// The analysis, **raw**: `[note_id]` markers included, because the widget that
  /// renders it is the only thing allowed to read them.
  final String text;

  /// Corpus ids the pipeline recorded beside the text. Merged with the inline
  /// ones by the grounded renderer so one claim shows one set of sources.
  final List<String> citations;

  /// The weakest evidence grade among the notes cited, when the server sent one.
  final String? gradeFloor;

  /// The pipeline declined to answer.
  final bool refused;

  /// The owner's plan does not include this card.
  final bool locked;

  /// Whether there is prose to show at all.
  bool get hasText => text.isNotEmpty && !refused && !locked;
}
