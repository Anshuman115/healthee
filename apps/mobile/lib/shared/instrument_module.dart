/// The instrument module — legacy's `HModule`, and the three parts inside it.
///
/// **Ported from** `healthee-legacy/app/lib/ui/ui.dart` (`HModule`, `HEyebrow`,
/// `HModuleValue`, `HFoot`), geometry unchanged:
///
/// ```text
///   ┌──────────────────────────┐
///   │ SLEEP                  ● │  eyebrow 9 px / 0.12 em · 6 px dot
///   │ 7:50 hrs                 │  figure 27 px, unit 10 px on the baseline
///   │ ▁▂▃▅▃▂▁                  │  the chart
///   │ DEEP 90  REM 90          │  foot, 9 px / 0.04 em, 8 px above
///   └──────────────────────────┘
///     14 px padding · squircle at r16 · 1 px border on the strong hairline
/// ```
///
/// ## What changed from the previous revision of this file
///
/// It was already a port, from the design bundle rather than from the Flutter
/// app, and three things had drifted. All three are now legacy's: **14 px**
/// padding (was 13), a **continuous-corner squircle** (was a rounded rectangle),
/// and **[HTap]'s press-scale** instead of an `InkWell` ripple — legacy's cards
/// scale to 97.5% under the finger and never ripple.
///
/// ## The dot
///
/// 6 px, top right, in the metric's own hue from `metric_hue.dart`. It ties the
/// card to its chart's tint, which is what makes a grid of eight modules
/// scannable. Note that legacy's hues include two that are also verdict colours
/// — `palette.dart` explains why that is a decision and not a defect.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/state_scaffold.dart';

/// One cell of the Today grid.
class InstrumentModule extends StatelessWidget {
  /// [label] names the metric; [tag] tints its dot and its chart.
  const InstrumentModule({
    required this.tag,
    required this.children,
    this.label,
    this.infoKey,
    this.trailing,
    this.onOpen,
    this.minHeight = 118,
    this.padding = _padding,
    super.key,
  }) : assert(
         infoKey == null || label != null,
         'An infoKey with no label is a DEAD CONTROL: the header row this ⓘ '
         'lives in is only drawn when a label exists, so the explainer is '
         'unreachable and nothing on screen shows that it is. Give the card a '
         'label, or drop the infoKey — the Sleep hero did the latter.',
       );

  /// The metric's name. Rendered uppercase by [ModuleLabel].
  ///
  /// **Null draws no header row at all**, which is legacy's `HModule` (`label`
  /// is nullable there and the whole `Row` plus its 9 px gap sit behind an
  /// `if`). The AI-analysis card is the live case: it draws its own title inside
  /// the body and an empty eyebrow above it would be 9 px of nothing.
  final String? label;

  /// Opens the plain-language explainer for this metric, when it has one.
  ///
  /// Legacy's `HModule.infoKey` — an ⓘ sits before [trailing] or the dot, and an
  /// unknown key draws nothing (`shared/metric_info/`).
  final String? infoKey;

  /// The metric's hue. Null draws no dot — for a module that has [trailing].
  final Color? tag;

  /// The module's body, top to bottom.
  final List<Widget> children;

  /// Drawn instead of the dot, for a module whose header carries a range.
  final Widget? trailing;

  /// What the module opens, or null when it is not a door.
  ///
  /// Legacy's grid cells all carry one (`onTap: () => onOpen('sleep')`) and its
  /// full-width modules do not — a 24-hour heart-rate strip is the detail, not
  /// an index of it.
  final VoidCallback? onOpen;

  /// The floor every grid cell shares, so a row's two cards match.
  final double minHeight;

  /// Inside the card. Legacy's `HModule` takes this too and three of its call
  /// sites pass their own — the readiness block at 18, the actions header at
  /// 15/13 (`today_screen.dart:572 · 922 · 973`).
  final EdgeInsets padding;

  /// Legacy's `EdgeInsets.all(14)`.
  static const EdgeInsets _padding = EdgeInsets.all(14);

  /// Legacy's `SizedBox(height: 9)` between the eyebrow row and the body.
  static const double _headerGap = 9;

  /// Legacy's 6 px identity mark.
  static const double _dotSize = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return HTap(
      onTap: onOpen,
      semanticLabel: onOpen == null ? null : '$label — open',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.surface,
          shape: StateCard.shapeOf(colors.line),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label case final String name when name.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(child: ModuleLabel(name)),
                      // Legacy's `[HInfoDot(infoKey), SizedBox(width: 8)]`.
                      if (infoKey case final String key) ...[
                        MetricInfoDot(key),
                        const SizedBox(width: Insets.sm),
                      ],
                      if (trailing case final Widget end)
                        end
                      else if (tag case final Color dot)
                        _TagDot(color: dot, size: _dotSize),
                    ],
                  ),
                  const SizedBox(height: _headerGap),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy's `HEyebrow` — uppercase, wide-tracked, quiet.
///
/// 9 px at 0.12 em of tracking, weight 400, in [HealtheeColors.ink3]. All of
/// those are legacy's; the face is Manrope rather than Space Mono, which is the
/// one typographic difference the port is allowed (`instrument_type.dart`).
///
/// The caps are **visual only**: the [Semantics] label carries the text as
/// written, because several screen readers spell an all-caps run out letter by
/// letter and "S-L-E-E-P" is not what this says.
class ModuleLabel extends StatelessWidget {
  /// Renders [text] as a module eyebrow.
  const ModuleLabel(this.text, {this.color, this.size = 9, this.tracking = 0.12, super.key});

  /// The label, in any case — this widget uppercases it.
  final String text;

  /// Overrides [HealtheeColors.ink3].
  final Color? color;

  /// Point size. 9 is legacy's `HEyebrow` default; its greeting date passes 10.
  final double size;

  /// Letter spacing in ems, as legacy passed it. 0.12 is the default; the
  /// greeting date passes 0.16 (`today_screen.dart:450`).
  final double tracking;

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
          style: HType.label(color ?? colors.ink3, size: size, tracking: tracking),
        ),
      ),
    );
  }
}

/// Legacy's `HModuleValue` — a figure with a small unit on its baseline.
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

  /// Legacy's unit: 10 px, weight 400, in ink3, 3 px after the figure.
  static const double _unitSize = 10;
  static const double _unitGap = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HType.number(color ?? colors.ink, size: size),
          ),
        ),
        if (unit case final String symbol) ...[
          const SizedBox(width: _unitGap),
          Text(
            symbol,
            style: HType.number(colors.ink3, size: _unitSize, weight: FontWeight.w400),
          ),
        ],
      ],
    );
  }
}

/// Legacy's `HFoot` — the one context line under a module's chart.
///
/// 9 px at 0.04 em, in ink3, with 8 px of air above it. Pushed to the bottom of
/// the module by a [Spacer] in the caller, exactly as legacy's `marginTop: auto`
/// did, so every card in a row aligns its foot.
class ModuleFoot extends StatelessWidget {
  /// Renders [text] as a module's foot.
  const ModuleFoot(this.text, {super.key});

  /// The context line — a median, a goal, a stage split.
  final String text;

  /// Legacy's `EdgeInsets.only(top: 8)`.
  static const EdgeInsets _padding = EdgeInsets.only(top: 8);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: _padding,
      child: Semantics(
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text.toUpperCase(),
            // Two lines, where legacy had one. Its feet were `GOAL 10,000 · 84%`;
            // several of ours have to name an instrument as well as a number
            // (`SINCE-MIDNIGHT COUNTER · 09:12`), and an attribution clipped to
            // an ellipsis is an attribution that did not happen. This is honesty
            // wording, which is the one category of change the port allows.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HType.label(colors.ink3, tracking: 0.04),
          ),
        ),
      ),
    );
  }
}

/// The 6 px identity mark in a module's corner. See the library docstring.
class _TagDot extends StatelessWidget {
  const _TagDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      // Decoration: the label beside it already names the metric, and a screen
      // reader announcing a colour would add nothing it can act on.
      child: const ExcludeSemantics(child: SizedBox.shrink()),
    );
  }
}
