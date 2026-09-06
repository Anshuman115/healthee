/// `.coach-intro` and `.prompt-button` — what the coach says before it is asked.
///
/// ```css
/// .coach-intro    { padding: 20px 0 }
/// .coach-symbol   { display:grid; place-items:center; width:56px; height:56px;
///                   border-radius:20px; background:var(--accent-soft);
///                   color:var(--accent); margin-bottom:20px }
/// .coach-symbol .icon { width:28px; height:28px }
/// .coach-intro h2 { font-size:26px; letter-spacing:-1px; line-height:1.35 }
/// .coach-intro p  { margin-top:12px; font-size:12px; line-height:1.9 }
/// ```
///
/// ## The three prompts are offered only when one can be spent
///
/// A prompt button asks a question, so it costs one of the owner's twenty. It is
/// therefore built under exactly the same rule as the text input: no permitting
/// balance, no control. `coach_sheet.dart` holds the rule; this widget takes
/// `onAsk` as **nullable and required**, so a caller cannot forget to decide.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/choices.dart';

/// The prototype's own heading, its line break included.
const String kCoachHeading = 'Let’s make sense\nof your day.';

/// And the sentence under it.
const String kCoachIntroBody =
    'Your measurements tell part of the story. Start with something you’ve been '
    'wondering about.';

/// The three openers, in the prototype's order and wording.
const List<String> kCoachPrompts = <String>[
  'What should I notice about my sleep?',
  'How is activity affecting my recovery?',
  'What does my HRV mean?',
];

/// The symbol, the heading, the sentence and the three prompts.
class CoachIntro extends StatelessWidget {
  /// [onAsk] of null draws the prompts as **absent**, not disabled.
  const CoachIntro({required this.onAsk, super.key});

  /// `.coach-intro { padding: 20px 0 }`.
  static const double verticalPadding = 20;

  /// `.coach-symbol { width: 56px; height: 56px }`.
  static const double symbolSize = 56;

  /// `.coach-symbol { border-radius: 20px }`.
  static const double symbolRadius = 20;

  /// `.coach-symbol .icon { width: 28px }`.
  static const double symbolIcon = 28;

  /// `.coach-symbol { margin-bottom: 20px }`.
  static const double symbolGap = 20;

  /// The symbol's box, so a test can measure it rather than guess which
  /// `Container` in the tree it is.
  static const Key symbolKey = ValueKey<String>('coach-intro.symbol');

  /// `.coach-intro p { margin-top: 12px }`.
  static const double bodyGap = 12;

  /// Asks one of [kCoachPrompts]. Null builds no prompt at all.
  final void Function(String question)? onAsk;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ask = onAsk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // `Align`, because the Column stretches and a stretched box is no
          // longer 56 wide. The symbol is a fixed square at the leading edge,
          // which is what a `56px` block in normal flow is.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              key: symbolKey,
              width: symbolSize,
              height: symbolSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(symbolRadius),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: symbolIcon,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(height: symbolGap),
          Text(
            kCoachHeading,
            style: TypeScale.coachIntroTitle.copyWith(color: colors.ink),
          ),
          const SizedBox(height: bodyGap),
          Text(
            kCoachIntroBody,
            style: TypeScale.coachBody.copyWith(color: colors.ink2),
          ),
          if (ask != null)
            for (final prompt in kCoachPrompts)
              PromptButton(prompt: prompt, onPressed: () => ask(prompt)),
        ],
      ),
    );
  }
}
