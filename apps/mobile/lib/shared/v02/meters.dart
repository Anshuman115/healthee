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

/// The dimension grid moved to `dimension_grid.dart` at the 400-line gate
/// (Standards section 1): a grid of independently-judged readings is not a
/// meter. Re-exported so every call site and its tests are unchanged and there
/// is still one definition.
export 'package:healthee/shared/v02/dimension_grid.dart'
    show Dimension, DimensionGrid;

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
      // **`stretch`, or this bar is invisible.** A `Row` hands its children
      // LOOSE cross-axis constraints, and a `DecoratedBox` with no child takes
      // the smallest size it is allowed — so every segment was 8px wide and
      // ZERO high, and the stack reserved its space and painted nothing. The
      // same failure as the two charts that shipped at zero height: the widget
      // was in the tree the whole time.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
  const Factor(
    this.label,
    this.fraction, {
    required this.tone,
    this.reading,
    this.reference,
  });

  /// The factor's name.
  final String label;

  /// How full its track is, 0–1, or null when there is no reading.
  final double? fraction;

  /// Which family the fill takes.
  final Tone tone;

  /// The number in the right-hand column. Null prints an em dash.
  final String? reading;

  /// Where this track's OWN zero-point sits, 0–1, or null when it has none.
  ///
  /// **A set of bars drawn identically claims they are one scale.** Recovery's
  /// four are not: three score the night against the owner's trailing 42 days,
  /// where the middle of the track is a normal night for them, and the fourth
  /// is a plain percentage of stored sleep need, where the middle is half the
  /// sleep they needed. So `Sleep 70` and `Resting heart 70` are unrelated news
  /// and the drawing said they were the same.
  ///
  /// A tick at the reference is the smallest honest repair: the three bars that
  /// HAVE a normal show where it is — fill past it reads as better than usual —
  /// and the one that does not visibly lacks it. The words are behind the ⓘ;
  /// this stops the picture asserting the thing the words have to deny.
  final double? reference;
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

  /// The reference tick's width. See [Factor.reference].
  static const double referenceWidth = 2;

  /// Identifies the FILL, so a test can count fills without counting ticks.
  ///
  /// Both are a `FractionallySizedBox`, and the claim one suite makes is that an
  /// unscored factor draws no fill — which silently became "draws no fill and no
  /// tick" the moment the tick existed, and passed for the wrong reason.
  static const Key fillKey = ValueKey<String>('factor.fill');

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
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ColoredBox(
                          color: colors.surface2,
                          child: factor.fraction == null
                              ? const SizedBox.shrink()
                              : FractionallySizedBox(
                                  key: FactorBars.fillKey,
                                  alignment: Alignment.centerLeft,
                                  widthFactor: factor.fraction!.clamp(0.0, 1.0),
                                  child: ColoredBox(color: context.family),
                                ),
                        ),
                      ),
                      if (factor.reference case final double at)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: at.clamp(0.0, 1.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              // Height stated, not inherited: `Align` gives
                              // loose constraints and a childless `ColoredBox`
                              // takes the smallest size allowed — which is how
                              // the weight stack above spent months invisible.
                              child: SizedBox(
                                width: FactorBars.referenceWidth,
                                height: FactorBars.trackHeight,
                                child: ColoredBox(color: colors.ink),
                              ),
                            ),
                          ),
                        ),
                    ],
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
