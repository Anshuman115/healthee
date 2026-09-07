/// What a `.three` or `.two` cell draws when the server had no figure for it.
///
/// ## The problem this solves, and why it is not [WithheldPanel]
///
/// [WithheldPanel] is v02's refusal: a metric's name, a 44 px hole and the
/// reason, in a dashed box. It is right for a **card about one number** — the
/// zones card, the effort card — and wrong inside a grid of three, where it
/// would replace a 22 px statistic with a 76 px box and turn a summary of a run
/// into a summary of what is missing from it. Four absent cells would be four
/// dashed boxes on a card with no numbers left on it at all.
///
/// So a grid cell with no reading **draws nothing** — [StatBlock] already does,
/// for a null value — and the card carries the refusals underneath, one line
/// each, in the server's own sentence. Both halves of the brief's rule hold: the
/// absent cell is absent rather than a dash, and the refusal is still on the
/// screen with its reason attached to the metric's name.
///
/// **This is the honesty layer, not the design.** The prototype has no element
/// for it — its fixture has every figure — so the shape is ours; the constraint
/// it is meeting is not.
///
/// An empty list draws nothing, including no gap: a card where everything was
/// measured must not reserve a band for the disclosure it does not have.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/reading.dart';

/// One figure a card wanted, named as the card would have named it.
@immutable
class RefusedFigure {
  /// [label] is the cell's own label, so the sentence names the same quantity
  /// the missing cell would have.
  const RefusedFigure(this.label, this.reading);

  /// The `.stat-label` this refusal stands in for.
  final String label;

  /// The reading. Anything but a [Withheld] contributes nothing.
  final Reading<Object> reading;
}

/// The refusals among [figures], one line each, under the grid they came from.
class RefusedFigures extends StatelessWidget {
  /// Builds the list. [figures] may hold readings that are present; those are
  /// skipped, so a call site passes its whole grid rather than pre-filtering it
  /// and getting the filter subtly wrong.
  const RefusedFigures(this.figures, {super.key});

  /// `.panel-note { margin-top: 12px }` — the gap above the first line.
  static const double topGap = 12;

  /// The gap between two refusals.
  static const double lineGap = 6;

  /// The grid's cells, present and absent alike.
  final List<RefusedFigure> figures;

  /// The refusals, in the order the cells were declared.
  List<RefusedFigure> get refused => <RefusedFigure>[
    for (final figure in figures)
      if (figure.reading is Withheld<Object>) figure,
  ];

  @override
  Widget build(BuildContext context) {
    final missing = refused;
    if (missing.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < missing.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: lineGap),
            Text(
              // The em dash carries the same meaning it carries in a cell —
              // "no reading" — and then the sentence says why, which is the
              // half a bare dash cannot.
              '${missing[i].label} — '
              '${(missing[i].reading as Withheld<Object>).disclosure.message}',
              style: TypeScale.panelNote.copyWith(color: colors.ink2),
            ),
          ],
        ],
      ),
    );
  }
}
