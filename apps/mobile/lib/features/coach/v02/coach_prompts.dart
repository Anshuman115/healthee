/// The three openers — one card of divided rows, not three bordered boxes.
///
/// The prototype draws each as its own `.prompt-button`: a 16 pt-padded box with
/// its own 14 pt border and a 10 pt gap to the next. Three of them stacked put
/// three borders, three gaps and three shadowed edges between the owner and the
/// screen's actual purpose, and on the owner's device they filled the space
/// between the masthead and the composer with repeated chrome. The owner asked
/// for the screen to look elegant, and the first thing elegance means here is
/// fewer edges.
///
/// So they become `.card.flush` + `.list-row`: one container, one border, a
/// hairline between rows — a shape this design system already has and already
/// uses for every other run of destinations in the app (`shared/v02/list_rows`).
/// Nothing about what a prompt IS changed; it is the same question, asked the
/// same way, at the same cost.
///
/// ## Still gated by the balance, and still structurally
///
/// A prompt asks a question, so it spends one of the owner's twenty. [onAsk] is
/// **nullable and required** for that reason and no other: a caller cannot build
/// this widget without having decided whether a question may be spent, and null
/// draws the prompts as ABSENT rather than as disabled decoration. That is the
/// same rule `CoachComposer` enforces by taking a non-null meter, and the same
/// rule `test/mutations.sh` breaks on purpose to check it is real.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/list_rows.dart';

/// The three openers, in the prototype's order and wording.
const List<String> kCoachPrompts = <String>[
  'What should I notice about my sleep?',
  'How is activity affecting my recovery?',
  'What does my HRV mean?',
];

/// The quiet label above them.
const String kCoachPromptsLabel = 'Or start with';

/// The openers, or nothing at all when none may be spent.
class CoachPrompts extends StatelessWidget {
  /// [onAsk] of null draws no prompts — absent, never disabled.
  const CoachPrompts({required this.onAsk, super.key});

  /// Asks one of [kCoachPrompts]. Null builds nothing.
  final void Function(String question)? onAsk;

  @override
  Widget build(BuildContext context) {
    final ask = onAsk;
    if (ask == null) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: Text(
            kCoachPromptsLabel,
            style: TypeScale.panelNote.copyWith(color: colors.ink3),
          ),
        ),
        FlushCard(
          rows: <Widget>[
            for (final prompt in kCoachPrompts)
              _PromptRow(prompt: prompt, onPressed: () => ask(prompt)),
          ],
        ),
      ],
    );
  }
}

/// One opener: the question, and an arrow saying it will be asked.
///
/// Deliberately NOT `V02ListRow`, which is this design system's row for reaching
/// an instrument. That row forces a tone-tinted [IconTile] and truncates its
/// title to one line, and both are wrong here:
///
/// * the tile carries an INSTRUMENT's identity — fitness green, sleep indigo —
///   and a suggested question is not a measurement. Rendered with one, three
///   green squares sat on a screen whose every other accent (the coach symbol,
///   the Ask button) is the app's amber. The clash was the first thing visible
///   on the device;
/// * a question is the row's whole content, so eliding it at one line hides the
///   thing being offered. These wrap to two.
///
/// The arrow is `--muted` rather than the accent: the accent on this screen
/// belongs to the Ask button, which is the control that spends. A row that
/// matched it would compete with the one thing the owner is meant to press.
class _PromptRow extends StatelessWidget {
  const _PromptRow({required this.prompt, required this.onPressed});

  /// `.list-row { min-height: 72px; padding: 16px 20px }`.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  );

  /// `.list-row { min-height: 72px }`.
  static const double minHeight = 72;

  /// `.list-row > .icon:last-child { width: 16px }`.
  static const double arrowSize = 16;

  final String prompt;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: padding,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  prompt,
                  style: TypeScale.panelTitle.copyWith(color: colors.ink),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: Insets.md),
              Icon(Icons.arrow_forward, size: arrowSize, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
