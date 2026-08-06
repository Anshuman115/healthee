/// The legend under a Sleep chart — **legacy's `_legendDot`, `_legendDashed` and
/// `_StageLegend`, unified**.
///
/// Legacy wrote the same 8 px dot, 6 px gap and `lbl(ink2, 9.5, 0.04)` label in
/// three places and a dashed variant in a fourth. All four are the same legend
/// with different keys, so they are one widget here (Standards §1) — the geometry
/// is unchanged and every call site passes legacy's own colours, labels and
/// spacing.
///
/// The naps legend is deliberately NOT drawn through this: legacy gives it a 2 px
/// corner, `sans(ink3, 9.5)` and 13 px of right padding rather than a wrap
/// spacing. Folding it in would have meant changing it.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';

/// One entry of a legend: a mark and what it means.
@immutable
class LegendKey {
  /// A solid 8 px square with a 2.5 px corner. Legacy's `_legendDot`.
  const LegendKey(this.color, this.label) : dashed = false;

  /// Three 4×2 ticks with a gap between them. Legacy's `_legendDashed`.
  const LegendKey.dashed(this.color, this.label) : dashed = true;

  /// The mark's colour.
  final Color color;

  /// What it means.
  final String label;

  /// Whether the mark is legacy's dashed run rather than its solid dot.
  final bool dashed;
}

/// A row of legend keys, wrapping when it runs out of width.
class SleepLegend extends StatelessWidget {
  /// [spacing] is legacy's per-call-site gap: 14 under a chart, 16 beside a pair.
  const SleepLegend(this.keys, {this.spacing = 14, super.key});

  /// The keys, in the order legacy draws them.
  final List<LegendKey> keys;

  /// The gap between keys.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = HType.label(colors.ink2, size: 9.5, tracking: 0.04);
    return Wrap(
      spacing: spacing,
      runSpacing: 6,
      children: <Widget>[
        for (final key in keys)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (key.dashed) _DashRun(color: key.color) else _Dot(color: key.color),
              SizedBox(width: key.dashed ? 3 : 6),
              Text(key.label, style: style),
            ],
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(2.5),
    ),
  );
}

/// Legacy's `_legendDashed`: three 4×2 ticks at 60% alpha, 2 px apart.
class _DashRun extends StatelessWidget {
  const _DashRun({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (var tick = 0; tick < 3; tick++) ...<Widget>[
        Container(width: 4, height: 2, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 2),
      ],
    ],
  );
}
