/// The legacy grid's component language: a module, its label, its value, its foot.
///
/// **Ported from** `design_reference/project/hh/ui.jsx` — `Module`,
/// `ModuleValue`, `Foot` and the `.lbl` class in `styles/hh.css`. Structure and
/// density are legacy's; type and colour are this app's.
///
/// ```text
///   ┌──────────────────────────┐
///   │ SLEEP                  ● │   label (uppercase, wide-tracked) + tag dot
///   │ 7:50 hrs                 │   value + unit, baseline-aligned
///   │ ▁▂▃▅▃▂▁                  │   the chart, pinned to the bottom
///   │ DEEP 90  REM 90          │   foot — the context line
///   └──────────────────────────┘
/// ```
///
/// ## What the dot is, and what it is not
///
/// Legacy put a 6 px coloured dot in every module's top-right corner and used it
/// to tie the card to its chart's tint. It is kept, and it carries an **identity
/// tag** from `metric_hues.dart` — a constant of the metric, never a function of
/// today's reading. `palette.dart` has the whole argument for why that is not the
/// product colouring a verdict.
///
/// ## Why the module is not a `StateCard`
///
/// It shares [StateCard]'s shape and hairline exactly — `StateCard.shapeOf` is
/// the single source of the corner — but not its padding. A `StateCard` is 15 px
/// all round because it holds prose; a module is 13 px because two of them sit
/// side by side on a 390 px phone and the difference is the sparkline having
/// somewhere to go. Passing an `EdgeInsets` into `StateCard` would have made the
/// padding a parameter of every card in the app to serve one screen.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// One cell of the Today grid.
class InstrumentModule extends StatelessWidget {
  /// [label] names the metric; [tag] tints its dot and its chart.
  const InstrumentModule({
    required this.label,
    required this.tag,
    required this.children,
    this.trailing,
    this.minHeight = 118,
    super.key,
  });

  /// The metric's name. Rendered uppercase by [ModuleLabel].
  final String label;

  /// The identity tag. Null draws no dot — for a module that has [trailing].
  final Color? tag;

  /// The module's body, top to bottom.
  final List<Widget> children;

  /// Drawn instead of the dot, for a module whose header carries a range.
  final Widget? trailing;

  /// The floor every grid cell shares, so a row's two cards match.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: StateCard.shapeOf(colors.line),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md + 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: ModuleLabel(label)),
                  if (trailing case final Widget end)
                    end
                  else if (tag case final Color dot)
                    _TagDot(color: dot),
                ],
              ),
              const SizedBox(height: 9),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy's `.lbl` — uppercase, wide-tracked, quiet.
///
/// The tracking is legacy's 0.12em and the case is legacy's. The face is
/// Instrument Sans rather than Space Mono, because this app vendors one family
/// (`typography.dart`) and a second one for label text is ~50 KB of binary for a
/// texture. Tabular figures are already on, which is the part of a mono face a
/// screen of numbers actually needed.
///
/// The caps are **visual only**: the [Semantics] label carries the text as
/// written, because several screen readers spell an all-caps run out letter by
/// letter and "S-L-E-E-P" is not what this says.
class ModuleLabel extends StatelessWidget {
  /// Renders [text] as a module eyebrow.
  const ModuleLabel(this.text, {this.color, super.key});

  /// The label, in any case — this widget uppercases it.
  final String text;

  /// Overrides [HealtheeColors.ink3].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color ?? colors.ink3,
            fontSize: 9.5,
            letterSpacing: 0.12 * 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Legacy's `ModuleValue` — a figure with a small unit on its baseline.
class ModuleValue extends StatelessWidget {
  /// [value] is already formatted; this widget does not round.
  const ModuleValue({required this.value, this.unit, this.color, this.size = 27, super.key});

  /// The formatted number.
  final String value;

  /// Its unit, or null when there is none.
  final String? unit;

  /// Overrides [HealtheeColors.ink] on the figure.
  final Color? color;

  /// The figure's size. 27 is legacy's grid module.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.displayLarge?.copyWith(
              fontSize: size,
              color: color ?? colors.ink,
              letterSpacing: -0.02 * size,
            ),
          ),
        ),
        if (unit case final String symbol) ...[
          const SizedBox(width: 3),
          Text(
            symbol,
            style: text.labelSmall?.copyWith(color: colors.ink3, fontSize: 10),
          ),
        ],
      ],
    );
  }
}

/// Legacy's `Foot` — the one context line under a module's chart.
///
/// Pushed to the bottom of the module by a [Spacer] in the caller, exactly as
/// legacy's `marginTop: 'auto'` did, so every card in a row aligns its foot.
class ModuleFoot extends StatelessWidget {
  /// Renders [text] as a module's foot.
  const ModuleFoot(this.text, {super.key});

  /// The context line — a median, a goal, a stage split.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Semantics(
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text.toUpperCase(),
            // Two lines, where legacy had one. Its feet were `GOAL 10,000 · 84%`;
            // several of ours have to name an instrument as well as a number
            // (`SINCE-MIDNIGHT COUNTER · 09:12`), and an attribution clipped to
            // an ellipsis is an attribution that did not happen.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.ink3,
              fontSize: 9,
              height: 1.35,
              letterSpacing: 0.04 * 9,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 6 px identity mark in a module's corner. See the library docstring.
class _TagDot extends StatelessWidget {
  const _TagDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      // Decoration: the label beside it already names the metric, and a screen
      // reader announcing a colour would add nothing it can act on.
      child: const ExcludeSemantics(child: SizedBox.shrink()),
    );
  }
}
