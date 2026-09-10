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
///
/// ## Two readers of one parse, and why they must not disagree
///
/// The prose and its grounding are now drawn in two different places — the
/// sentence on the card, the sources in that card's ⓘ. [groundingOf] is what
/// both of them call, so "what does this prose cite" has ONE answer. A card that
/// computed its own id list would be a second implementation of the grammar
/// three lines from the first, and the failure mode is silent: the sentence
/// keeps its marker stripped and the sheet shows a different set of sources.
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

/// Everything backing one claim: the corpus, the owner's own data, and the
/// brackets that resolved to neither.
///
/// The three travel together on purpose. They are the three ways a claim can be
/// grounded — a published source, a pattern in this one person's history, and a
/// reference we could not read — and a surface that carried one without the
/// others would be showing the flattering subset. `MetricDetail.grounded` takes
/// this whole object rather than its parts for exactly that reason.
@immutable
class Grounding {
  /// Built by [groundingOf] / [groundingOfAll].
  const Grounding({
    required this.noteIds,
    required this.personalFindings,
    required this.unresolved,
  });

  /// Nothing cited anything — the bundle a claim with no grounding carries.
  static const Grounding none = Grounding(
    noteIds: <String>[],
    personalFindings: <String>[],
    unresolved: <String>[],
  );

  /// The corpus ids: those written inline in the prose, then those the payload
  /// sent in a structured field beside it, each appearing once.
  final List<String> noteIds;

  /// The `[personal_finding:<name>]` names cited. Never merged into [noteIds];
  /// see the library docstring.
  final List<String> personalFindings;

  /// Bracketed runs that yielded no citation at all. Kept, and shown.
  final List<String> unresolved;

  /// True when there is nothing here to show and no ⓘ worth drawing.
  bool get isEmpty =>
      noteIds.isEmpty && personalFindings.isEmpty && unresolved.isEmpty;

  /// The negation, for a call site that reads better positively.
  bool get isNotEmpty => !isEmpty;
}

/// What [text] cites, merged with the ids the payload sent beside it.
///
/// The one answer to that question. See the library docstring's second section.
Grounding groundingOf(
  String text, {
  List<String> alsoCites = const <String>[],
}) => groundingOfAll(<String>[text], alsoCites: alsoCites);

/// The same, for a card carrying several pieces of prose about one subject.
///
/// A recommendation's action, its rationale and its expected effect are three
/// sentences about one suggestion, and they share the rec's `research_note_ids`.
/// One subject gets one set of sources; two subjects get two ⓘ — the rule
/// `shared/findings_section.dart` states, because a merged sheet would tell the
/// reader either claim is backed by either source.
///
/// Nulls are skipped, so a call site can pass an optional field straight in
/// rather than composing the list around it.
Grounding groundingOfAll(
  Iterable<String?> texts, {
  List<String> alsoCites = const <String>[],
}) {
  final noteIds = <String>[];
  final personal = <String>[];
  final unresolved = <String>[];
  for (final text in texts) {
    if (text == null) {
      continue;
    }
    final parsed = parseGrounded(text);
    _addAll(noteIds, parsed.noteIds);
    _addAll(personal, parsed.personalFindings);
    // Not de-duplicated against the others: two brackets we could not read are
    // two things the reader is owed, even when they read the same.
    unresolved.addAll(parsed.unresolved);
  }
  _addAll(noteIds, alsoCites);
  return Grounding(
    noteIds: noteIds,
    personalFindings: personal,
    unresolved: unresolved,
  );
}

/// Appends [from] to [into], in order, without repeats.
void _addAll(List<String> into, Iterable<String> from) {
  for (final value in from) {
    if (!into.contains(value)) {
      into.add(value);
    }
  }
}

/// Closes the holes a removed marker leaves.
///
/// Removing `[note_id]` from `… movement [recovery_readiness], consider …` leaves
/// a double space before the comma, and from the end of a sentence it leaves a
/// space before the full stop. Neither is visible in a diff and both are visible
/// on a phone.
///
/// ## The empty backticks, which shipped
///
/// The model writes citations as `` `[note_id]` `` — wrapped in code ticks —
/// because the system prompt's own examples are written that way and it copies
/// the house style. Stripping the bracket then left the ticks behind, so Sleep
/// read *"…a rolling sleep debt of 1,793 minutes ``."* on a real phone.
///
/// It is a cosmetic bug in the one place the product cannot afford one: the
/// sentence carrying a claim, with the mark of its evidence turned into
/// punctuation noise. The marker is stripped by meaning, so its wrapper has to go
/// with it.
String _tidy(String text) => text
    // Ticks orphaned by a removed marker: `` and ` ` and `​`. Not backticks in
    // general — a pair with anything between them is somebody's code span and is
    // theirs to keep.
    .replaceAll(RegExp(r'`[ \t]*`'), '')
    .replaceAllMapped(RegExp(r'[ \t]+([.,;:!?])'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .trim();
