/// `<details><summary>See dated readings</summary>` and the `.data-table`
/// behind it.
///
/// ```css
/// .data-table            { width:100%; border-collapse:collapse;
///                          font-size:11px }
/// .data-table th         { color:var(--muted); font-weight:400;
///                          text-align:left; padding-block:8px }
/// .data-table td         { border-top:1px solid var(--line);
///                          padding-block:12px }
/// .data-table td:last-child,
/// .data-table th:last-child { text-align:right }
/// summary.small          { font-size:12px }
/// .section               { margin-top:24px }
/// ```
///
/// ## Why the plotted values are also a list
///
/// A chart is a shape; the table is the numbers. The prototype puts every
/// plotted observation behind one disclosure so a reading can be checked rather
/// than estimated off an axis, and so a screen reader has a route to the series
/// that is not a `CustomPaint`. `charts/v02/chart_scrub.dart` gives the chart
/// its own readout; this is the same data at rest.
///
/// ## The substitution
///
/// HTML `<details>` is a disclosure with a rotating marker and no animation
/// specified. Flutter has no such element, so this is the rendered result: a
/// tappable summary row carrying the same triangle, and the rows below it
/// mounted or not. `ExpansionTile` was the alternative and it brings Material's
/// own 56 px row, its divider and its leading/trailing slots — a different
/// piece of furniture wearing this one's name.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/core/theme/type_scale_forms.dart';

/// One row of a `.data-table`: a label on the left, a figure on the right.
@immutable
class ReadingRow {
  /// Builds a row. [value] is already formatted — this widget never rounds.
  const ReadingRow(this.label, this.value);

  /// The left column. Usually a date.
  final String label;

  /// The right column, right-aligned.
  final String value;
}

/// A `<details>` disclosure over a `.data-table`.
class DatedReadings extends StatefulWidget {
  /// Builds the disclosure. An empty [rows] draws **nothing at all** — a
  /// summary that opens onto an empty table is a control that lies about
  /// having something behind it.
  const DatedReadings({
    required this.summary,
    required this.columns,
    required this.rows,
    super.key,
  });

  /// `.section { margin-top: 24px }` — the gap above the summary.
  static const double topGap = 24;

  /// `.data-table th { padding-block: 8px }`.
  static const double headPadding = 8;

  /// `.data-table td { padding-block: 12px }`.
  static const double rowPadding = 12;

  /// The marker's size and the gap after it.
  static const double markerSize = 10;

  /// The same.
  static const double markerGap = 6;

  /// The summary's own words — `See dated readings`.
  final String summary;

  /// The two column headings, left then right.
  final (String, String) columns;

  /// The rows, in the order they are to be read.
  final List<ReadingRow> rows;

  @override
  State<DatedReadings> createState() => _DatedReadingsState();
}

class _DatedReadingsState extends State<DatedReadings> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: DatedReadings.topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _open,
            label: widget.summary,
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: () => setState(() => _open = !_open),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: <Widget>[
                    Icon(
                      _open ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: DatedReadings.markerSize,
                      color: colors.ink2,
                    ),
                    const SizedBox(width: DatedReadings.markerGap),
                    Text(
                      widget.summary,
                      style: FormType.small.copyWith(color: colors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) _DataTable(columns: widget.columns, rows: widget.rows),
        ],
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({required this.columns, required this.rows});

  final (String, String) columns;
  final List<ReadingRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final head = TypeScale.tinyLabel.copyWith(color: colors.ink2);
    final cell = TypeScale.tinyLabel.copyWith(color: colors.ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: DatedReadings.headPadding,
          ),
          child: _Cells(columns.$1, columns.$2, style: head),
        ),
        for (final row in rows)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.line, width: hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DatedReadings.rowPadding,
              ),
              child: _Cells(row.label, row.value, style: cell),
            ),
          ),
      ],
    );
  }
}

class _Cells extends StatelessWidget {
  const _Cells(this.left, this.right, {required this.style});

  final String left;
  final String right;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      // `Expanded` on the left and the figure intrinsic beside it. Two
      // `Flexible`s would split the row in half and ellipsize a date that fits.
      Expanded(child: Text(left, style: style)),
      Text(right, style: style, textAlign: TextAlign.right),
    ],
  );
}
