/// `.comparison-chart` — one quantity beside the quantity it was compared as.
///
/// ```css
/// .comparison-chart  { margin-top: 14px }
/// .comparison-row    { display:grid; grid-template-columns:60px minmax(0,1fr) 46px;
///                      gap:10px; align-items:center; margin:12px 0;
///                      font-size:10px }
/// .comparison-bar    { height:7px; background:var(--surface-soft);
///                      border-radius:4px }
/// .comparison-bar i  { display:block; height:100%; border-radius:4px;
///                      background:var(--family) }
/// ```
///
/// ## The scale is derived, because the prototype's is not a scale
///
/// The prototype hard-codes `70%` and `77.7%` for 6.3 h and 7.0 h — an implied
/// 9-hour axis that exists nowhere in the payload. A bar length is chart craft,
/// and the honest version of it is a scale the data supplies: **every bar is
/// drawn against the largest quantity in the set**, so the two lengths are in
/// the same ratio to each other that the numbers are, and no reference the
/// server did not send is implied by the axis.
///
/// A row whose value is null draws its track and no fill — the same rule
/// `meters.dart` keeps for a factor with no reading, and for the same reason: a
/// zero-length bar is a measurement of zero.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/meter_type_scale.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// One row of a [ComparisonBars].
@immutable
class ComparisonBar {
  /// [value] is the quantity; [reading] is how it should be printed.
  const ComparisonBar(this.label, this.value, this.reading);

  /// What this quantity is.
  final String label;

  /// The quantity itself, in whatever unit the set shares. Null draws no fill.
  final double? value;

  /// The quantity as the owner should read it, unit included.
  final String reading;
}

/// `.comparison-chart` — two or more quantities on one derived scale.
class ComparisonBars extends StatelessWidget {
  /// Builds the rows, top to bottom. An empty [bars] draws nothing.
  const ComparisonBars(this.bars, {super.key});

  /// `.comparison-chart { margin-top: 14px }`.
  static const double topGap = 14;

  /// `.comparison-row { grid-template-columns: 60px … 46px }`.
  static const double labelWidth = 60;
  static const double readingWidth = 46;

  /// `.comparison-row { gap: 10px }`.
  static const double columnGap = 10;

  /// `.comparison-row { margin: 12px 0 }`.
  static const double rowGap = 12;

  /// `.comparison-bar { height: 7px; border-radius: 4px }`.
  static const double barHeight = 7;
  static const double barRadius = 4;

  /// The quantities, in the order they should be read.
  final List<ComparisonBar> bars;

  /// The scale every bar is drawn against; see the library docstring.
  static double? scaleOf(List<ComparisonBar> bars) {
    double? largest;
    for (final bar in bars) {
      final value = bar.value;
      if (value != null && value.isFinite && (largest == null || value > largest)) {
        largest = value;
      }
    }
    return largest == null || largest <= 0 ? null : largest;
  }

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) {
      return const SizedBox.shrink();
    }
    final scale = scaleOf(bars);
    return Padding(
      padding: const EdgeInsets.only(top: topGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < bars.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: rowGap),
            _ComparisonRow(bar: bars[i], scale: scale),
          ],
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.bar, required this.scale});

  final ComparisonBar bar;
  final double? scale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = bar.value;
    final fraction = scale == null || value == null ? null : value / scale!;
    return Row(
      children: <Widget>[
        SizedBox(
          width: ComparisonBars.labelWidth,
          child: Text(
            bar.label,
            style: MeterType.comparisonRow.copyWith(color: colors.ink2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: ComparisonBars.columnGap),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ComparisonBars.barRadius),
            child: SizedBox(
              height: ComparisonBars.barHeight,
              child: ColoredBox(
                color: colors.surface2,
                child: fraction == null
                    ? const SizedBox.shrink()
                    : FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: ColoredBox(color: context.family),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: ComparisonBars.columnGap),
        SizedBox(
          width: ComparisonBars.readingWidth,
          child: Text(
            bar.reading,
            textAlign: TextAlign.right,
            style: MeterType.comparisonRow.copyWith(color: colors.ink),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}
