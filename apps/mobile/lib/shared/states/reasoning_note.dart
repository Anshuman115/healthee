/// Reasoning **offered**, never forced — an inline disclosure, never a modal.
///
/// Brief §3: *"'Why debt is 120 minutes, not 1,400', 'What would restore this'
/// as an expandable, never a modal."* The distinction is the product's whole
/// posture towards depth. A modal stops the person reading their sleep and
/// demands they deal with a footnote; a line they can open is a footnote a
/// serious user will love and a casual one will never notice.
///
/// So this is an `ExpansionTile`-shaped thing built by hand, because Material's
/// own comes with a leading chevron, a divider, and a tap target sized for a
/// settings list — three pieces of chrome around one sentence.
///
/// It renders **inside** whatever card it belongs to and draws no frame of its
/// own: brief §2's first "never" is card-inside-a-card.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// A one-line question that opens into its answer.
class ReasoningNote extends StatefulWidget {
  /// [question] is the prompt in the owner's own words; [answer] is the body.
  const ReasoningNote({
    required this.question,
    required this.answer,
    super.key,
  });

  /// "Why debt is 120 minutes, not 1,400" — phrased as the thing somebody
  /// actually wonders, not as "Details".
  final String question;

  /// The explanation. Plain, specific, second person.
  final String answer;

  @override
  State<ReasoningNote> createState() => _ReasoningNoteState();
}

class _ReasoningNoteState extends State<ReasoningNote> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(Radii.chip),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.question,
                    style: text.labelMedium?.copyWith(color: colors.accent),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: colors.accent,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              widget.answer,
              style: text.bodySmall?.copyWith(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}
