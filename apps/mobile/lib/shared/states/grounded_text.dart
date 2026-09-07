/// The ONE way generated prose reaches the screen.
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
/// So the parse is not exposed to feature code as a string function. This widget
/// takes the RAW string and renders the prose without its markers; there is no
/// parameter that hands it a pre-stripped sentence.
///
/// ## Where the citations went, and what still holds them here
///
/// They used to be drawn underneath, by a [CitationRow] this widget built. The
/// owner asked three times for them off the card faces — *"info sheets are for
/// that"* — so they now live in the card's ⓘ, and this widget renders prose and
/// nothing else.
///
/// That move is only safe because **the argument above did not weaken, it moved
/// with them**:
///
///   * the ids are read by `groundingOf`, the same pure function this widget's
///     call sites hand their ⓘ, so the sentence and the sheet cannot disagree
///     about what the prose cites;
///   * `MetricDetail.grounded` takes the whole [Grounding] rather than three
///     lists, so a card cannot route the note ids to its ⓘ and leave the
///     single-subject findings or the unreadable markers behind;
///   * `test/features/citation_sweep_test.dart` names every call site and reads
///     the ids back out of its ⓘ. Dropping the grounding is no longer one
///     character; it is a failing test with the call site's own name on it.
///
/// ## What it does with a marker it cannot resolve
///
/// Nothing quiet. `data/honesty/citations.dart` leaves a bracket that yields no
/// citation **in the sentence**, and the ⓘ states plainly that it is there and
/// could not be resolved. The alternative — strip anything bracket-shaped —
/// would let the app delete a claim's grounding, or a chunk of its prose, on the
/// strength of a guess. A visible oddity beats an invisible deletion every time,
/// and this is the surface where that is not a matter of taste.
///
/// ## Where it is used
///
/// Every field on the wire that a model wrote: `/api/today`'s `action`, and each
/// recommendation's `action`, `expected_effect` and `rationale`. `ReasoningNote`
/// renders its body through this too, so prose put behind a disclosure tomorrow
/// is covered by construction rather than by review.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/honesty/citations.dart';

/// One piece of server-authored prose, with its markers rendered rather than
/// printed. Its sources are in the ⓘ of the card that draws it.
class GroundedProse extends StatelessWidget {
  /// [text] is the raw field off the wire, markers included.
  const GroundedProse({
    required this.text,
    this.style,
    this.maxLines,
    super.key,
  });

  /// The sentence as the server sent it. Never pre-stripped by the caller.
  final String text;

  /// How to draw the prose. Defaults to the ambient body style.
  final TextStyle? style;

  /// Clamps the prose to this many lines, with an ellipsis. Null is unbounded.
  ///
  /// Added for the collapsed action row on Today, which legacy draws as a single
  /// line (`today_screen.dart:980`) and expands on tap.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final prose = parseGrounded(text).prose;
    if (prose.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      prose,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
