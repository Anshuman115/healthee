/// `.coach-form` — the input, and the cost printed on the control beside it.
///
/// ```css
/// .coach-form       { display:flex; gap:8px; margin-top:24px }
/// .coach-form input { width:100%; min-height:48px; padding:12px;
///                     border-radius:12px; border:1px solid var(--rule);
///                     background:var(--surface); font-size:16px }
/// .form-note        { font-size:10px; margin-block:16px }
/// ```
///
/// ## The one substitution on this screen, and why it is forced
///
/// The prototype's send control is an **arrow with no label**, because a scripted
/// preview costs nothing. A question here costs one of twenty per rolling thirty
/// days, and the rule is that the cost is on the button *before* the tap — a
/// meter at the top of a sheet and a bare arrow at the bottom is still a spend
/// the owner has to remember to have read about.
///
/// So the button carries `Ask — uses 1 of your 17` **and** the prototype's arrow.
/// A label that long does not fit beside an input at 320 px, so the row is
/// measured: it stays the prototype's single row wherever the label and a usable
/// input both fit, and the button drops to its own full-width line where they do
/// not. That is the rendered result of the same CSS at a narrower width, which is
/// the rule for anything Flutter cannot express directly.
///
/// ## It cannot be constructed without a decision about the balance
///
/// [remaining] is `int?` and means *how many are left, or uncapped* — it is never
/// "unknown". A sheet that has not read the meter does not build this widget at
/// all; see `coach_sheet.dart`.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/v02/controls.dart';

/// What the ask button says. Public so a test can pin the wording.
String askLabel(int? remaining) =>
    remaining == null ? 'Ask' : 'Ask — uses 1 of your $remaining';

/// The input a permitting balance licenses.
class CoachComposer extends StatefulWidget {
  /// [remaining] is the server's own count, or null for an uncapped account.
  const CoachComposer({
    required this.asking,
    required this.remaining,
    required this.onAsk,
    super.key,
  });

  /// `margin-top: 24px`.
  static const double topGap = 24;

  /// `gap: 8px`.
  static const double gap = 8;

  /// `min-height: 48px`.
  static const double fieldHeight = 48;

  /// `border-radius: 12px`.
  static const double fieldRadius = 12;

  /// The narrowest an input may be and still be one — under this the row wraps.
  static const double minFieldWidth = 132;

  /// Whether the prototype's single row survives with [wanted] px of button in
  /// [available] px of composer.
  ///
  /// A pure function rather than an expression inside `build`, because the
  /// rendered layout **cannot** be asked this in a widget test: `flutter test`
  /// substitutes a fixed-width test font, which measures this button's label at
  /// roughly twice its real width and so wraps at every phone size. A geometry
  /// assertion would therefore be green whatever this decided. The rendered
  /// invariant — the input is never narrower than [minFieldWidth] and the button
  /// never leaves the page — is asserted separately and holds in both branches.
  static bool fitsOneRow(double available, double wanted) =>
      available - wanted - gap >= minFieldWidth;

  /// Whether a question is in flight.
  final bool asking;

  /// How many are left, or null when the account is uncapped.
  final int? remaining;

  /// Asks one.
  final void Function(String question) onAsk;

  @override
  State<CoachComposer> createState() => _CoachComposerState();
}

class _CoachComposerState extends State<CoachComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final question = _controller.text.trim();
    if (question.isEmpty || widget.asking) {
      return;
    }
    _controller.clear();
    widget.onAsk(question);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = askLabel(widget.remaining);
    final button = ActionButton(
      label: label,
      trailingIcon: Icons.arrow_forward,
      onPressed: widget.asking ? null : _send,
    );
    final field = TextField(
      controller: _controller,
      enabled: !widget.asking,
      minLines: 1,
      maxLines: 4,
      style: TypeScale.inputText.copyWith(color: colors.ink),
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _send(),
      decoration: InputDecoration(
        hintText: 'What’s on your mind?',
        isDense: true,
        contentPadding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: CoachComposer.fieldHeight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachComposer.fieldRadius),
          borderSide: BorderSide(color: colors.rule, width: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachComposer.fieldRadius),
          borderSide: BorderSide(color: colors.rule, width: hairline),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: CoachComposer.topGap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wanted = _buttonWidth(context, label);
          if (CoachComposer.fitsOneRow(constraints.maxWidth, wanted)) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: field),
                const SizedBox(width: CoachComposer.gap),
                button,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              field,
              const SizedBox(height: CoachComposer.gap),
              ActionButton(
                label: label,
                trailingIcon: Icons.arrow_forward,
                full: true,
                onPressed: widget.asking ? null : _send,
              ),
            ],
          );
        },
      ),
    );
  }

  /// How wide the button wants to be: its label, its padding, its gap, its icon.
  static double _buttonWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: TypeScale.buttonLabel),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width +
        ActionButton.padding.horizontal +
        ActionButton.gap +
        Insets.lg;
  }
}
