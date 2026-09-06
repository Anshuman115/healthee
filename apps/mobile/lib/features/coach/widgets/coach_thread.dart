/// The conversation, drawn — `.coach-message` in its two shapes, plus trouble.
///
/// ```css
/// .coach-message      { margin-top:20px; padding:16px; border-radius:18px;
///                       font-size:12px; line-height:1.9;
///                       background:var(--surface); color:var(--ink);
///                       border:1px solid var(--line) }
/// .coach-message.user { background:var(--accent-soft); margin-left:28px;
///                       border:0 }
/// ```
///
/// The coach's own prose goes through [GroundedProse] like every other field a
/// model wrote in this app: the raw string with its `[note_id]` markers, rendered
/// as a sentence with its sources under it, and no parameter that turns the
/// second half off.
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
///
/// A [CoachTrouble] wears the same bubble. It is not an error banner: a failure
/// that looked different from the rest of the thread would read as the app
/// breaking rather than as an answer about the question that was asked.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/coach/coach_answer.dart';
import 'package:healthee/features/coach/coach_conversation.dart';
import 'package:healthee/shared/states/grounded_text.dart';

/// One entry of the thread.
class CoachEntryView extends StatelessWidget {
  /// Draws [entry] in whichever of the three shapes it is.
  const CoachEntryView({required this.entry, super.key});

  /// `.coach-message { margin-top: 20px }`.
  static const double topGap = 20;

  /// `.coach-message { padding: 16px }`.
  static const double padding = 16;

  /// `.coach-message { border-radius: 18px }`.
  static const double radius = 18;

  /// `.coach-message.user { margin-left: 28px }`.
  static const double userIndent = 28;

  /// The entry.
  final CoachEntry entry;

  @override
  Widget build(BuildContext context) {
    // Exhaustive over the sealed union: a fourth kind is a compile error here
    // rather than a row that draws nothing.
    return switch (entry) {
      OwnerQuestion(:final text) => _Bubble(
        mine: true,
        child: Builder(
          builder: (context) => Text(
            text,
            style: TypeScale.coachBody.copyWith(color: context.colors.ink),
          ),
        ),
      ),
      CoachReply(:final answer) => _Bubble(child: _Reply(answer: answer)),
      final CoachTrouble trouble => _Bubble(child: _Trouble(trouble: trouble)),
    };
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child, this.mine = false});

  final Widget child;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        top: CoachEntryView.topGap,
        left: mine ? CoachEntryView.userIndent : 0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(CoachEntryView.padding),
        decoration: BoxDecoration(
          // `accentSoft`, which is the colour of an ACTION in this app — asking
          // is one. It says nothing about the owner's body, which is the only
          // thing `fav`/`unf`/`alert` are allowed to say.
          color: mine ? colors.accentSoft : colors.surface,
          border: mine
              ? null
              : Border.all(color: colors.line, width: hairline),
          borderRadius: BorderRadius.circular(CoachEntryView.radius),
        ),
        child: child,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!answer.validated) ...<Widget>[
          Text(
            "The coach couldn't answer that one to its own standard, so this "
            'is the honest fallback rather than the answer you asked for. It '
            'was not counted against your questions.',
            style: TypeScale.tinyLabel.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: 12),
        ],
        GroundedProse(
          text: answer.reply,
          style: TypeScale.coachBody.copyWith(color: colors.ink),
          alsoCites: answer.citations,
          // The weakest grade among the notes cited. Never inferred — the
          // server sends it or it is absent, and absent renders nothing.
          grade: answer.gradeFloor,
        ),
      ],
    );
  }
}

class _Trouble extends StatelessWidget {
  const _Trouble({required this.trouble});

  final CoachTrouble trouble;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          trouble.message,
          style: TypeScale.rowTitle.copyWith(color: colors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          // Never silent about the meter. "A spend must never be silent" cuts
          // both ways: a question that was NOT charged has to say so too, or
          // the owner is left counting their own.
          trouble.spent
              ? 'This question was counted. The number above is the server’s '
                    'own, re-read just now.'
              : 'Nothing was counted for this. The number above is the '
                    'server’s own, re-read just now.',
          style: TypeScale.tinyLabel.copyWith(color: colors.ink2),
        ),
      ],
    );
  }
}
