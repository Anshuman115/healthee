/// `.metric-list` — the explorer's grid, and one tile in it.
///
/// ```css
/// .metric-list        { display:grid; grid-template-columns:repeat(2,minmax(0,1fr));
///                       gap:12px }
/// .metric-list a      { background:var(--surface); color:var(--ink);
///                       border:1px solid var(--line); border-radius:16px;
///                       padding:16px }
/// .metric-list a      { border-top:2px solid var(--family) }   /* richer.css */
/// .metric-list p      { font-size:10px }
/// .metric-list strong { font-size:20px; letter-spacing:-.6px;
///                       color:var(--family) }
/// .tiny-label         { font-size:11px; color:var(--subtle) }
/// ```
///
/// The 2 px top rule is the family's, and it is the only place on this screen a
/// colour appears. It is an **identity** — `shared/v02/metric_tone.dart` takes
/// an id and nothing else — so a tile cannot come out green because the owner
/// had a good day. `metric_polarity.dart` is the other table and it licenses
/// the only colour on this app's screens that is a verdict.
///
/// ## A refusal is a refusal, in a tile
///
/// The prototype has one absent state and it is `H.formatReading(null)` — an em
/// dash under the caption *"A dash means no measurement on that day"*. This app
/// has a second one the prototype has no data for: the server carried the
/// metric and **withheld** it, with a sentence saying why. That sentence is not
/// dropped to fit the tile. It replaces the unit line, so the tile reads
/// `Weight / — / your last weigh-in is 41 days old`, and it is
/// `WithheldPanel`'s contract at a tile's size rather than a new one.
///
/// ## Why `IntrinsicHeight` and not a `GridView`
///
/// CSS grid stretches every cell in a row to the tallest of them, and a metric
/// with a long refusal sentence is taller than its neighbour. A `GridView` needs
/// one extent for every cell in the grid, which would either clip that sentence
/// or pad twenty tiles to the height of the worst one. A row of stretched cells
/// is the rendered result of the CSS.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/v02/metric_tone.dart';

/// One metric's place in the explorer: what it is, and what it last read.
@immutable
class MetricEntry {
  /// [reading] is the day's value with its honesty state; null means the app
  /// holds no reading for this metric at all.
  const MetricEntry({
    required this.metric,
    required this.title,
    required this.unit,
    required this.value,
    this.reading,
  });

  /// The server's canonical id — the tone and the route are both read from it.
  final String metric;

  /// The owner-facing name, from `shared/format/metric_names.dart`.
  final String title;

  /// The unit, as the server names it. Empty draws no unit.
  final String unit;

  /// The figure, already formatted. Null draws the em dash.
  final String? value;

  /// The honesty state behind [value], when the payload carried one.
  final Reading<double>? reading;
}

/// The two-column grid of [MetricEntry] tiles.
class MetricGrid extends StatelessWidget {
  /// Builds the grid. [onOpen] of null draws tiles that do not navigate.
  const MetricGrid({required this.entries, this.onOpen, super.key});

  /// `gap: 12px`, both ways.
  static const double gap = 12;

  /// `grid-template-columns: repeat(2, minmax(0, 1fr))`.
  static const int columns = 2;

  /// What to draw, in order.
  final List<MetricEntry> entries;

  /// Opens one metric's own history.
  final void Function(String metric)? onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += columns) {
      final row = entries.skip(i).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var c = 0; c < columns; c++) ...<Widget>[
                if (c > 0) const SizedBox(width: gap),
                Expanded(
                  // A short last row keeps its columns rather than letting one
                  // tile span the width — `minmax(0, 1fr)` does not reflow.
                  child: c < row.length
                      ? MetricTile(entry: row[c], onOpen: onOpen)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }
}

/// One `.metric-list a`.
class MetricTile extends StatelessWidget {
  /// Builds the tile.
  const MetricTile({required this.entry, this.onOpen, super.key});

  /// `padding: 16px`.
  static const double padding = 16;

  /// `border-radius: 16px`.
  static const double radius = 16;

  /// `border-top: 2px solid var(--family)`.
  static const double topRule = 2;

  /// The gap under the title. `.metric-list strong` is a block after a `p`.
  static const double titleGap = 8;

  /// `.hero-number .unit`-style gap between the figure and its unit.
  static const double unitGap = 4;

  /// What this tile is about.
  final MetricEntry entry;

  /// Opens the metric's history.
  final void Function(String metric)? onOpen;

  @override
  Widget build(BuildContext context) {
    final open = onOpen;
    return ToneScope(
      tone: toneForMetric(entry.metric),
      child: Builder(
        builder: (context) {
          final tile = _Face(entry: entry);
          return open == null
              ? tile
              : Semantics(
                  button: true,
                  label: '${entry.title} history',
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      onTap: () => open(entry.metric),
                      behavior: HitTestBehavior.opaque,
                      child: tile,
                    ),
                  ),
                );
        },
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.entry});

  final MetricEntry entry;

  @override
  Widget build(BuildContext context) {
    // **The substitution.** CSS lets `border-top: 2px` and the other three
    // edges at 1px coexist under one `border-radius`; Flutter's `BoxDecoration`
    // asserts a UNIFORM border whenever a radius is set, and a non-uniform one
    // throws at paint time. So the rule is a clipped band laid over the top
    // edge, which is the rendered result: 2 px of family across the top, the
    // corners cut by the same 16 px arc, and the other three edges the ordinary
    // line. `ClipRRect` rather than a `Border` per edge, because the arc is what
    // makes the band read as part of the tile rather than a bar above it.
    return ClipRRect(
      borderRadius: BorderRadius.circular(MetricTile.radius),
      child: Stack(
        children: <Widget>[
          _body(context),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: MetricTile.topRule,
              // Resolved here from the enclosing `ToneScope`, never handed in.
              child: ColoredBox(color: context.family),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final colors = context.colors;
    final family = context.family;
    final withheld = entry.reading;
    final refusal = withheld is Withheld<double>
        ? withheld.disclosure.message
        : null;
    return Container(
      padding: const EdgeInsets.all(MetricTile.padding),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: hSquircle(
          MetricTile.radius,
          side: BorderSide(color: colors.line, width: hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            entry.title,
            style: TypeScale.tileTitle.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: MetricTile.titleGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  entry.value ?? '—',
                  style: TypeScale.metricListValue.copyWith(color: family),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
              if (entry.value != null && entry.unit.isNotEmpty) ...<Widget>[
                const SizedBox(width: MetricTile.unitGap),
                Text(
                  entry.unit,
                  style: TypeScale.tinyLabel.copyWith(color: colors.ink3),
                ),
              ],
            ],
          ),
          // The server's own sentence, not a shortened one. A refusal that fits
          // by being trimmed is a refusal that stopped saying what to do.
          if (refusal case final String message) ...<Widget>[
            const SizedBox(height: MetricTile.unitGap),
            Text(
              message,
              style: TypeScale.tinyLabel.copyWith(color: colors.ink2),
            ),
          ],
        ],
      ),
    );
  }
}
