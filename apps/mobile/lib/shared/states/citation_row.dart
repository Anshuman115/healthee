/// The evidence line under a claim: which notes back it, and how strongly.
///
/// ## Grades are shown only where the server sent one
///
/// This is the rule the whole file exists to hold. `/api/today` carries a real
/// evidence grade in exactly one place — `recommendations[].evidence_grade`,
/// which `jobs/recs.py::_provable_grade` has already replaced with the weakest
/// grade among the notes the rec actually cites. Everywhere else the payload
/// carries `research_notes`: **citation ids, with no grade attached**.
///
/// So [grade] is optional and is never inferred from an id. Deriving one would
/// rebuild the `evidence_grade`-vs-`grade` split that once published a `Myth`
/// note as `Established` (#83) — a second grade that can disagree with the
/// first — and it would do it in the one layer with no access to the corpus.
///
/// Ids are rendered as chips rather than hidden behind a "sources" toggle,
/// because brief §4.5 is explicit: sources are a feature, not clutter. They are
/// not tappable yet — the note reader is a later screen — and a chip that looks
/// tappable and is not would be its own small lie, so they are drawn as stamps.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The notes behind a claim, with an optional evidence grade.
class CitationRow extends StatelessWidget {
  /// [noteIds] are corpus ids; [grade] is shown only when the server sent one.
  const CitationRow({
    required this.noteIds,
    this.grade,
    this.source,
    super.key,
  });

  /// The research-note ids licensing the claim above.
  final List<String> noteIds;

  /// `Established` / `Probable`, when the payload carried a grade. Never guessed.
  final String? grade;

  /// A human sentence about the source, when the payload carried one — VO₂max's
  /// `see_source` ("Carrier 2023: MAPE 6.85% vs lab CPET") is the live example.
  /// Rendered verbatim; it is the server's calibrated wording.
  final String? source;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (noteIds.isEmpty && grade == null && source == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (grade case final String label) _GradeStamp(label: label),
            for (final id in noteIds) _NoteStamp(id: id),
          ],
        ),
        if (source case final String sentence) ...[
          const SizedBox(height: Insets.xs),
          Text(sentence, style: text.labelSmall?.copyWith(color: colors.ink3)),
        ],
      ],
    );
  }
}

/// The grade, as a word. Accent-outlined, never filled — it is a qualification
/// on a claim, not a badge to be pleased about.
class _GradeStamp extends StatelessWidget {
  const _GradeStamp({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colors.accent, width: hairline),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.accent, letterSpacing: 0.7),
      ),
    );
  }
}

/// One corpus id, drawn as a quiet stamp.
class _NoteStamp extends StatelessWidget {
  const _NoteStamp({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border.all(color: colors.line2, width: hairline),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        id,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.ink3),
      ),
    );
  }
}
