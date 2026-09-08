/// The three meters a model card is made of — weights, factors, dimensions.
///
/// ```css
/// .weight-stack     { display:flex; height:8px; gap:3px; margin:12px 0; }
/// .weight-stack i   { background:var(--family); border-radius:3px; }
/// .factor-bars      { display:grid; gap:12px; margin-block:16px; }
/// .factor-row       { display:grid; grid-template-columns:85px 1fr 28px;
///                     gap:12px; font-size:11px; align-items:center; }
/// .factor-track     { height:6px; border-radius:6px;
///                     background:var(--surface-soft); overflow:clip; }
/// [data-tone] .factor-track i { background:var(--family); }
/// .dimension-grid   { display:grid; grid-template-columns:repeat(2,1fr);
///                     gap:20px 16px; }
/// .dimension-cell>span   { font-size:11px; color:var(--muted); }
/// .dimension-cell strong { font-size:22px; display:block;
///                          letter-spacing:-.7px; }
/// .dimension-cell small  { font-size:9px; display:block; margin-top:6px;
///                          color:var(--muted); }
/// ```
///
/// ## Every segment declares a TONE, and none of them takes a colour
///
/// A weight stack is four bars in four different families, inside one card that
/// already has a family of its own — the exact shape that tempts a `Color`
/// parameter. `richer.css` does it by putting `data-tone` on each `<i>`, and so
/// does this: [WeightSegment] and [Factor] carry a [Tone], each segment wraps
/// itself in a `ToneScope`, and the fill resolves `context.family` from there.
/// Naming a category is not passing a hue — `chart_ink.dart` makes the same
/// argument for `LinkedPane`.
///
/// A factor with a null reading draws its **track and no fill**, and prints its
/// own em dash in the value column. A zero-width fill would be a factor scored
/// zero, which is a measurement; this is the absence of one.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One share of a [WeightStack].
@immutable
class WeightSegment {
  /// [weight] is a share, not a width — the stack normalises them.
  const WeightSegment(this.tone, this.weight);

  /// Which family this share is drawn in.
  final Tone tone;

  /// Its share of the whole.
  final double weight;
}

/// `.weight-stack` — how a model divides itself, at a glance.
class WeightStack extends StatelessWidget {
  /// Builds the stack. An empty [segments] draws nothing.
  const WeightStack(this.segments, {super.key});

  /// `.weight-stack { height: 8px }`.
  static const double height = 8;

  /// `.weight-stack { gap: 3px }`.
  static const double gap = 3;

  /// `.weight-stack i { border-radius: 3px }`.
  static const double radius = 3;

  /// The shares, left to right.
  final List<WeightSegment> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < segments.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              flex: (segments[i].weight * 100).round().clamp(1, 100000),
              child: ToneScope(
                tone: segments[i].tone,
                child: Builder(
                  builder: (context) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.family,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of a [FactorBars].
@immutable
class Factor {
  /// [fraction] of null draws an empty track and an em dash.
  const Factor(this.label, this.fraction, {required this.tone, this.reading});

  /// The factor's name.
  final String label;

  /// How full its track is, 0–1, or null when there is no reading.
  final double? fraction;

  /// Which family the fill takes.
  final Tone tone;

  /// The number in the right-hand column. Null prints an em dash.
  final String? reading;
}

/// `.factor-bars` — the components behind one number, each in its own family.
class FactorBars extends StatelessWidget {
  /// Builds the rows, top to bottom.
  const FactorBars(this.factors, {super.key});

  /// `.factor-bars { gap: 12px }`.
  static const double rowGap = 12;

  /// `.factor-row { grid-template-columns: 85px … }`.
  static const double labelWidth = 85;

  /// `… 1fr 28px }`.
  static const double readingWidth = 28;

  /// `.factor-row { gap: 12px }`.
  static const double columnGap = 12;

  /// `.factor-track { height: 6px; border-radius: 6px }`.
  static const double trackHeight = 6;

  /// Its radius, which is its height.
  static const double trackRadius = 6;

  /// The factors, in the order the model lists them.
  final List<Factor> factors;

  @override
  Widget build(BuildContext context) {
    if (factors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < factors.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: rowGap),
          _FactorRow(factor: factors[i]),
        ],
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final Factor factor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ToneScope(
      tone: factor.tone,
      child: Builder(
        builder: (context) => Row(
          children: <Widget>[
            SizedBox(
              width: FactorBars.labelWidth,
              child: Text(
                factor.label,
                style: TypeScale.factorRow.copyWith(color: colors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: FactorBars.columnGap),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(FactorBars.trackRadius),
                child: SizedBox(
                  height: FactorBars.trackHeight,
                  child: ColoredBox(
                    color: colors.surface2,
                    child: factor.fraction == null
                        ? const SizedBox.shrink()
                        : FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: factor.fraction!.clamp(0.0, 1.0),
                            child: ColoredBox(color: context.family),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: FactorBars.columnGap),
            SizedBox(
              width: FactorBars.readingWidth,
              child: Text(
                factor.reading ?? '—',
                textAlign: TextAlign.right,
                style: TypeScale.factorRow.copyWith(color: colors.ink),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cell of a [DimensionGrid].
@immutable
class Dimension {
  /// [note] is the reference the reading is read against.
  const Dimension(this.label, this.value, {this.note});

  /// What is being measured.
  final String label;

  /// The reading, already formatted.
  final String value;

  /// The reference under it.
  final String? note;
}

/// `.dimension-grid` — independent readings, two across, never summed.
class DimensionGrid extends StatelessWidget {
  /// Builds the grid. An empty [dimensions] draws nothing.
  const DimensionGrid(this.dimensions, {super.key});

  /// `.dimension-grid { gap: 20px 16px }` — the row half.
  static const double rowGap = 20;

  /// Its column half.
  static const double columnGap = 16;

  /// `.dimension-cell small { margin-top: 6px }`.
  static const double noteGap = 6;

  /// The readings, in payload order.
  final List<Dimension> dimensions;

  @override
  Widget build(BuildContext context) {
    if (dimensions.isEmpty) {
      return const SizedBox.shrink();
    }
    final rows = <List<Dimension>>[
      for (var i = 0; i < dimensions.length; i += 2)
        dimensions.sublist(i, (i + 2).clamp(0, dimensions.length)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var r = 0; r < rows.length; r++) ...<Widget>[
          if (r > 0) const SizedBox(height: rowGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _Cell(dimension: rows[r].first)),
              const SizedBox(width: columnGap),
              Expanded(
                child: rows[r].length > 1
                    ? _Cell(dimension: rows[r][1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.dimension});

  final Dimension dimension;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          dimension.label,
          style: TypeScale.dimensionLabel.copyWith(color: colors.ink2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          dimension.value,
          style: TypeScale.dimensionValue.copyWith(color: colors.ink),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
        if (dimension.note case final String note) ...<Widget>[
          const SizedBox(height: DimensionGrid.noteGap),
          Text(
            note,
            style: TypeScale.dimensionNote.copyWith(color: colors.ink2),
          ),
        ],
      ],
    );
  }
}
