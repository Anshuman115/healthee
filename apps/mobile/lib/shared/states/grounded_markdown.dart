/// Generated prose that arrives as **markdown**, with its grounding intact.
///
/// ## Why this exists beside [GroundedProse] rather than inside it
///
/// The daily action is one sentence; `/api/sleep/insight` and
/// `/api/activity/insight` return several paragraphs of markdown — `**bold**`,
/// `* ` bullets and `**Header:**` lines. `renderInsightMarkdown`
/// (`healthee-legacy/app/lib/ui/ai_insight.dart:85`) is what draws them, and a
/// plain `Text` would print the asterisks. So the *structure* is legacy's,
/// verbatim: the same header/bullet/paragraph rules, the same sizes, the same
/// accent bullet dot.
///
/// [GroundedProse] stays a plain `Text` because that is right for a sentence, and
/// putting a markdown parser behind every `action` field would make the common
/// case pay for the rare one. Both take the **raw** string and neither offers a
/// way to drop the citations — that rule is the point of both files.
///
/// ## The one thing that is not legacy's
///
/// Legacy collected the `[citation]` markers itself and drew each as
/// `ct.replaceAll('_', ' ')` — `sleep_regularity_index` printed as "sleep
/// regularity index". That is an internal id with its underscores taken out, on a
/// health screen, presented as a source. Here the parse is
/// `data/honesty/citations.dart` (the server's own grammar, shared with every
/// other surface) and the chips are [CitationRow]'s, which resolve each id to the
/// corpus's own NAME and say so plainly when they cannot. That is honesty
/// wording, which is the one category of change this port allows.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/shared/states/citation_row.dart';

/// A block of server-authored markdown, with the sources it names underneath.
class GroundedMarkdown extends StatelessWidget {
  /// [text] is the raw field off the wire, markers included.
  const GroundedMarkdown({
    required this.text,
    required this.accent,
    this.grade,
    this.alsoCites = const <String>[],
    super.key,
  });

  /// The analysis as the server sent it. Never pre-stripped by the caller.
  final String text;

  /// Colours the bullet dots. Legacy passes the section's own hue.
  final Color accent;

  /// An evidence grade the payload sent alongside, or null. Never inferred.
  final String? grade;

  /// Ids the payload carried in a structured field beside the prose — the
  /// insight's `citations`. Merged with the inline ones so one analysis shows
  /// one set of sources rather than two rows that disagree.
  final List<String> alsoCites;

  @override
  Widget build(BuildContext context) {
    final parsed = parseGrounded(text);
    final ids = <String>[
      ...parsed.noteIds,
      for (final id in alsoCites)
        if (!parsed.noteIds.contains(id)) id,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._blocks(context, parsed.prose),
        if (ids.isNotEmpty ||
            parsed.personalFindings.isNotEmpty ||
            parsed.unresolved.isNotEmpty ||
            grade != null) ...[
          const SizedBox(height: Insets.xs),
          CitationRow(
            noteIds: ids,
            personalFindings: parsed.personalFindings,
            unresolved: parsed.unresolved,
            grade: grade,
          ),
        ],
      ],
    );
  }

  /// Legacy's line loop: blank → 10 px of air, `**Header:**` → a label,
  /// `* item` → an accent bullet, anything else → a paragraph.
  List<Widget> _blocks(BuildContext context, String prose) {
    final colors = context.colors;
    final blocks = <Widget>[];
    for (final raw in prose.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 10));
        continue;
      }
      final header = _header.firstMatch(line);
      if (header != null) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              header.group(1)!.toUpperCase(),
              style: HType.label(colors.ink2, size: 9.5, tracking: 0.1),
            ),
          ),
        );
        continue;
      }
      final bullet = _bullet.firstMatch(line);
      blocks.add(
        bullet != null
            ? _Bullet(text: bullet.group(1)!, accent: accent)
            : Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text.rich(
                  TextSpan(
                    style: HType.sans(colors.ink, height: 1.55),
                    children: boldSpans(line),
                  ),
                ),
              ),
      );
    }
    return blocks;
  }

  static final RegExp _header = RegExp(r'^\*\*(.+?)\*\*:?$');
  static final RegExp _bullet = RegExp(r'^[*\-]\s+(.+)$');
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 9),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: HType.sans(colors.ink, size: 13.5, height: 1.5),
                children: boldSpans(text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Splits [text] on `**bold**` markers into styled spans. Legacy's `_boldSpans`.
///
/// Public because the tests assert the split rather than the pixels: a renderer
/// that silently dropped the bold text would still look plausible in a screenshot.
List<TextSpan> boldSpans(String text) {
  final spans = <TextSpan>[];
  final bold = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final match in bold.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(
      TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return spans.isEmpty ? <TextSpan>[TextSpan(text: text)] : spans;
}
