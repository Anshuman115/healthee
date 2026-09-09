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

/// The prototype's own heading, its line break included.
const String kCoachHeading = 'Let’s make sense\nof your day.';

/// And the sentence under it.
const String kCoachIntroBody =
    'Your measurements tell part of the story. Start with something you’ve been '
    'wondering about.';

/// The symbol, the heading and the sentence. The openers moved to [CoachPrompts].
///
/// They moved because the ASK BOX now comes before them. The primary action of a
/// screen whose whole purpose is asking a question was sitting below three
/// suggestion boxes and off the bottom of the owner's phone; the openers are the
/// fallback for someone who has nothing in mind, and a fallback does not belong
/// above the thing it is a fallback for.
class CoachIntro extends StatelessWidget {
  /// Built only when the thread is empty; carries no controls of its own.
  const CoachIntro({super.key});

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The symbol sits BESIDE the heading rather than stacked above it.
          //
          // The prototype stacks (`.coach-symbol { margin-bottom: 20px }`) and
          // this app followed it, which cost 56 + 20 pt of column before the
          // first word. Measured on the owner's own device that opening block —
          // symbol, two-line heading, paragraph — ran to roughly a quarter of a
          // 2400 px screen before anything could be tapped, and the owner asked
          // for the screen to be cleaner. Beside it, the same two elements read
          // as one masthead and the prompts come up the page.
          //
          // Every token is the prototype's; only the axis changed.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
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
              const SizedBox(width: symbolGap),
              Expanded(
                child: Text(
                  kCoachHeading,
                  style: TypeScale.coachIntroTitle.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: bodyGap),
          Text(
            kCoachIntroBody,
            style: TypeScale.coachBody.copyWith(color: colors.ink2),
          ),
        ],
      ),
    );
  }
}
