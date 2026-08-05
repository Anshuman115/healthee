/// The conversation, drawn — three entry kinds, none of which renders blank.
///
/// The coach's own prose goes through [GroundedProse] like every other field a
/// model wrote in this app: the raw string with its `[note_id]` markers, rendered
/// as a sentence with its sources under it, and no parameter that turns the
/// second half off. `shared/states/grounded_text.dart` argues why that is a widget
/// rather than a helper function.
///
/// Two pieces of response metadata ride on the citation row rather than beside it:
///
///   * **`grade_floor`** — the weakest evidence grade among the notes cited. It is
///     the answer's own statement of how firm it is, and `INTELLIGENCE §3` makes
///     it part of the response rather than a nicety. `null` means nothing
///     gradeable was cited, which is not a weak grade and is not rendered as one.
///   * **`validated: false`** — the blocking validator rejected the model's answer
///     and the honest fallback shipped. That is the product working, and it is
///     also not the answer the owner asked for, so it says both.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/coach/coach_answer.dart';
import 'package:healthee/features/coach/coach_conversation.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// One entry of the thread.
class CoachEntryView extends StatelessWidget {
  /// Draws [entry] in whichever of the three shapes it is.
  const CoachEntryView({required this.entry, super.key});

  /// The entry.
  final CoachEntry entry;

  @override
  Widget build(BuildContext context) {
    // Exhaustive over the sealed union: a fourth kind is a compile error here
    // rather than a row that draws nothing.
    return switch (entry) {
      OwnerQuestion(:final text) => _Question(text: text),
      CoachReply(:final answer) => _Reply(answer: answer),
      final CoachTrouble trouble => _Trouble(trouble: trouble),
    };
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        decoration: ShapeDecoration(
          // `accentSoft`, which is the colour of an ACTION in this app — asking is
          // one. It says nothing about the owner's body, which is the only thing
          // `fav`/`unf`/`alert` are allowed to say (README, "Colour is a claim").
          color: colors.accentSoft,
          shape: StateCard.shapeOf(colors.line2),
        ),
        child: Text(text, style: style.bodyMedium?.copyWith(color: colors.ink)),
      ),
    );
  }
}

class _Reply extends StatelessWidget {
  const _Reply({required this.answer});

  final CoachAnswer answer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!answer.validated) ...[
            Text(
              "The coach couldn't answer that one to its own standard, so this "
              'is the honest fallback rather than the answer you asked for. It '
              'was not counted against your questions.',
              style: text.bodySmall?.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: Insets.sm),
          ],
          GroundedProse(
            text: answer.reply,
            style: text.bodyMedium,
            alsoCites: answer.citations,
            // The weakest grade among the notes cited. Never inferred — the
            // server sends it or it is absent, and absent renders nothing.
            grade: answer.gradeFloor,
          ),
        ],
      ),
    );
  }
}

class _Trouble extends StatelessWidget {
  const _Trouble({required this.trouble});

  final CoachTrouble trouble;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return StateCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trouble.message, style: text.titleSmall),
          const SizedBox(height: Insets.sm),
          Text(
            // Never silent about the meter. "A spend must never be silent" cuts
            // both ways: a question that was NOT charged has to say so too, or
            // the owner is left counting their own.
            trouble.spent
                ? 'This question was counted. The number above is the server’s '
                      'own, re-read just now.'
                : 'Nothing was counted for this. The number above is the '
                      'server’s own, re-read just now.',
            style: text.bodySmall?.copyWith(color: colors.ink3),
          ),
        ],
      ),
    );
  }
}
