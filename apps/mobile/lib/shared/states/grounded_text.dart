/// The ONE way generated prose reaches the screen — sentence and grounding, in
/// one widget, inseparable.
///
/// ## What went wrong, and why a helper function would not have fixed it
///
/// The daily action rendered its `[note_id]` markers as literal text. The narrow
/// fix is a `stripCitations(text)` call at that one call site; the reason this is
/// a widget instead is that a strip function makes **dropping the grounding one
/// character cheaper than keeping it**. `Text(stripCitations(sentence))` compiles,
/// reads fine in review, and silently deletes the thing this product exists to
/// show. The honesty contract cannot rest on a caller remembering the second
/// line.
///
/// So the parse is not exposed to feature code at all. This widget takes the RAW
/// string, renders the prose without its markers, and renders the citations
/// underneath. There is no parameter that turns the second half off.
///
/// ## What it does with a marker it cannot resolve
///
/// Nothing quiet. `data/honesty/citations.dart` leaves a bracket that yields no
/// citation **in the sentence**, and `CitationRow` states plainly underneath that
/// it is there and could not be resolved. The alternative — strip anything
/// bracket-shaped — would let the app delete a claim's grounding, or a chunk of
/// its prose, on the strength of a guess. A visible oddity beats an invisible
/// deletion every time, and this is the surface where that is not a matter of
/// taste.
///
/// ## Where it is used
///
/// Every field on the wire that a model wrote: `/api/today`'s `action`, and each
/// recommendation's `action`, `expected_effect` and `rationale`. `ReasoningNote`
/// renders its body through this too, so prose put behind a disclosure tomorrow
/// is covered by construction rather than by review.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/shared/states/citation_row.dart';

/// One piece of server-authored prose, with the sources it names.
class GroundedProse extends StatelessWidget {
  /// [text] is the raw field off the wire, markers included.
  const GroundedProse({
    required this.text,
    this.style,
    this.grade,
    this.source,
    this.alsoCites = const <String>[],
    super.key,
  });

  /// The sentence as the server sent it. Never pre-stripped by the caller.
  final String text;

  /// How to draw the prose. Defaults to the ambient body style.
  final TextStyle? style;

  /// An evidence grade the payload sent alongside, or null. Never inferred.
  final String? grade;

  /// The server's own sentence about the source, when it sent one.
  final String? source;

  /// Ids the payload carried in a structured field beside this prose — a
  /// recommendation's `research_note_ids`. Merged with the inline ones so one
  /// claim shows one set of sources rather than two rows that disagree.
  final List<String> alsoCites;

  @override
  Widget build(BuildContext context) {
    final parsed = parseGrounded(text);
    final ids = <String>[
      ...parsed.noteIds,
      for (final id in alsoCites)
        if (!parsed.noteIds.contains(id)) id,
    ];
    if (parsed.prose.isEmpty && parsed.isBare && ids.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsed.prose.isNotEmpty) Text(parsed.prose, style: style),
        if (ids.isNotEmpty ||
            parsed.personalFindings.isNotEmpty ||
            parsed.unresolved.isNotEmpty ||
            grade != null ||
            source != null) ...[
          if (parsed.prose.isNotEmpty) const SizedBox(height: Insets.sm),
          CitationRow(
            noteIds: ids,
            personalFindings: parsed.personalFindings,
            unresolved: parsed.unresolved,
            grade: grade,
            source: source,
          ),
        ],
      ],
    );
  }
}
