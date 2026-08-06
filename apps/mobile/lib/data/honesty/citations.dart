/// Reading the grounding out of generated prose — the client half of the
/// citation contract.
///
/// ## The bug this exists to close
///
/// The daily action rendered on screen, literally:
///
/// > Since your recovery supports moderate movement **[recovery_readiness]**,
/// > consider taking a short walk … **[specificity_and_recovery]**.
///
/// `[note_id]` is the grounded-ask citation format. The **server is right to
/// emit it** — `insights/answer_text.py::extract_citations` is what the blocking
/// validator reads, and a claim with no marker never ships. The last hop was
/// wrong: it printed the marker instead of rendering it.
///
/// ## The grammar is the server's, and it is copied deliberately
///
/// `answer_text.py` splits every bracket on commas and classifies each part
/// independently, because a bracket may MIX kinds
/// (`[personal_finding:x, note_id]`) and an earlier pair of whole-bracket
/// regexes lost a real citation on exactly that shape. [parseGrounded] does the
/// same, in the same order, for the same reason.
///
/// This is a second implementation of one grammar, which the standards normally
/// forbid. It is unavoidable — one is Python on the server and one is Dart on the
/// phone — so it is made cheap to check instead: the parse is a pure function
/// with the server's own edge cases as its tests, and it is the ONLY place in the
/// app that knows what a bracket means.
///
/// ## What is stripped, and what is left alone
///
/// **A bracket is removed from the sentence only if it yields at least one
/// citation.** A bracket that classifies to nothing is not grounding — it is
/// prose the model happened to write in brackets, or a truncation — and deleting
/// it would be the app editing a claim it does not understand. It stays in the
/// text and comes back in [GroundedText.unresolved] so the surface can say so.
/// That is the answer to "what does an unresolvable marker do": it is loud, and
/// it is never a quiet strip.
///
/// The two kinds do NOT merge. A `personal_finding` is a single-subject
/// observation from this owner's own history and a note id is the research
/// corpus; rendering one as the other would give an n-of-1 correlation the
/// standing of a literature review.
library;

import 'package:meta/meta.dart';

/// Any `[...]` run with no nested brackets — the server's `_BRACKET_RE`.
final RegExp _bracket = RegExp(r'\[([^\[\]]+)\]');

/// A citable corpus id — the server's `_NOTE_ID_RE`.
final RegExp _noteId = RegExp(r'^[a-z0-9_]+$');

/// The server's `_PERSONAL_PREFIX`. Matched case-insensitively, as it is there.
const String _personalPrefix = 'personal_finding:';

/// One piece of generated prose, split into what it says and what backs it.
@immutable
class GroundedText {
  /// Built by [parseGrounded].
  const GroundedText({
    required this.prose,
    required this.noteIds,
    required this.personalFindings,
    required this.unresolved,
  });

  /// The sentence with every resolved citation marker removed, and the spacing
  /// left readable.
  final String prose;

  /// The corpus ids cited, in the order they appeared, without repeats.
  final List<String> noteIds;

  /// The personal-finding names cited, in order, without repeats.
  final List<String> personalFindings;

  /// Bracketed runs that yielded no citation at all, verbatim and without their
  /// brackets. Non-empty means the surface owes the reader a notice — see the
  /// library docstring.
  final List<String> unresolved;

  /// True when nothing backs this text and nothing needs saying about it.
  bool get isBare =>
      noteIds.isEmpty && personalFindings.isEmpty && unresolved.isEmpty;
}

/// Splits [raw] into prose and its citations.
///
/// Pure and total: no input throws, and text with no brackets comes back
/// unchanged with three empty lists.
GroundedText parseGrounded(String raw) {
  final noteIds = <String>[];
  final personal = <String>[];
  final unresolved = <String>[];
  final prose = raw.replaceAllMapped(_bracket, (match) {
    final parts = match.group(1)!.split(',');
    var citations = 0;
    for (final raw in parts) {
      final part = raw.trim();
      if (part.toLowerCase().startsWith(_personalPrefix)) {
        final name = part.substring(_personalPrefix.length).trim();
        if (name.isEmpty) {
          continue;
        }
        citations++;
        if (!personal.contains(name)) {
          personal.add(name);
        }
      } else if (_noteId.hasMatch(part)) {
        citations++;
        if (!noteIds.contains(part)) {
          noteIds.add(part);
        }
      }
    }
    if (citations > 0) {
      return '';
    }
    // Not a citation. Kept, and reported — see the library docstring.
    unresolved.add(match.group(1)!.trim());
    return match.group(0)!;
  });
  return GroundedText(
    prose: _tidy(prose),
    noteIds: noteIds,
    personalFindings: personal,
    unresolved: unresolved,
  );
}

/// Closes the holes a removed marker leaves.
///
/// Removing `[note_id]` from `… movement [recovery_readiness], consider …` leaves
/// a double space before the comma, and from the end of a sentence it leaves a
/// space before the full stop. Neither is visible in a diff and both are visible
/// on a phone.
String _tidy(String text) => text
    .replaceAllMapped(RegExp(r'[ \t]+([.,;:!?])'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .trim();
