/// What a series is READ AGAINST — the shared scale, and the line drawn on it.
///
/// ## Why this file exists
///
/// Owner report, 2026-08-06, on the installed build: *"can we change the
/// heartrate, stress, hrv, blood oxygen graphs to be more meaningful ones, this
/// graphs all look similar."* They did, and the cause was structural rather than
/// cosmetic: all four were `HArea(series, color: tint, height: 52)` — a value
/// over time with **no reference**. Four different questions got one answer
/// shape, and none of the four answers could actually be read. 47 ms of HRV
/// means nothing without the owner's own normal beside it.
///
/// **This is an owner-directed departure from the verbatim-legacy rule**
/// (`feedback_port_legacy_design_verbatim`). Legacy draws no reference on any of
/// these four charts. Each card records the departure at its own site.
///
/// ## The one rule this file exists to enforce
///
/// A reference line is truthful only if it is drawn **in the same y-scale as the
/// series**, and only if that scale was widened to contain it. A resting-HR line
/// at 55 under a trace spanning 60–112 would otherwise clip to the bottom edge
/// and read as "you never went below your resting rate" — a false claim produced
/// entirely by layout. So [ChartScale.of] takes the reference values as
/// `include`, and a painter and its reference cannot disagree about where a
/// number sits.
///
/// ## Structure, not verdict
///
/// A reference is drawn in a quiet ink and **never** in `fav`/`unf`/`alert`.
/// `palette.dart` rations those three to judgement, and a line saying "here is
/// your normal" is not a judgement about the reading beside it. The two kinds
/// differ by **dash**, not by hue:
///
///   * [ChartReferenceKind.personalBaseline] — solid. The owner's own number, as
///     the **server** defines it. The client never computes one: `CLAUDE.md`'s
///     one-definition-per-metric rule is exactly what a second, on-device
///     baseline would break.
///   * [ChartReferenceKind.convention] — dashed, and its label says so. A
///     borrowed line that is not a measurement of this owner at all. The
///     blood-oxygen ~92% is the live case: `wearable_spo2_validity` is explicit
///     that it is *"a clinical convention, not a wearable-validated cutoff —
///     none is sourced (#98)"*. Drawing it exactly like a personal baseline
///     would assert it as a fact about this owner's oxygen.
library;

import 'package:flutter/material.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

/// Whose number a reference line is.
enum ChartReferenceKind {
  /// The owner's own normal, from the server's baseline. Drawn solid.
  personalBaseline,

  /// A borrowed line that is not a measurement of this owner. Drawn dashed, and
  /// its label must say what it is. See the library docstring.
  convention,
}

/// One horizontal line a series is read against.
@immutable
class ChartReference {
  /// The owner's own normal — a server-computed baseline and nothing else.
  const ChartReference.personalBaseline({
    required this.value,
    required this.label,
  }) : kind = ChartReferenceKind.personalBaseline;

  /// A published convention. [label] MUST name it as one; see the library
  /// docstring and `wearable_spo2_validity` D2.
  const ChartReference.convention({required this.value, required this.label})
    : kind = ChartReferenceKind.convention;

  /// Where the line sits, in the series' own units.
  final double value;

  /// The short caption drawn beside it.
  final String label;

  /// Whose number this is.
  final ChartReferenceKind kind;

  /// Whether this line is drawn broken. See the library docstring.
  bool get isDashed => kind == ChartReferenceKind.convention;
}

/// The value→y mapping a series and its references MUST share.
///
/// The geometry is [HArea]'s, extracted verbatim so that extending that chart
/// with a reference could not quietly move the curve it has always drawn: the
/// same 0.18 padding fraction, the same 3 px inset top and bottom. The only
/// addition is `include`, and with no references it changes nothing — the
/// existing chart tests are the proof.
@immutable
class ChartScale {
  /// Prefer [ChartScale.of].
  const ChartScale(this.low, this.high);

  /// The scale that fits [data] **and every value in [include]**.
  ///
  /// [include] is what makes a reference honest rather than decorative: a line
  /// outside the data's own range widens the chart instead of clipping to an
  /// edge. See the library docstring.
  factory ChartScale.of(
    List<double> data, {
    Iterable<double> include = const <double>[],
    double pad = padFraction,
  }) {
    final values = <double>[...data, ...include];
    if (values.isEmpty) {
      return const ChartScale(0, 1);
    }
    var min = values.first;
    var max = values.first;
    for (final value in values) {
      if (value < min) {
        min = value;
      }
      if (value > max) {
        max = value;
      }
    }
    final span = (max - min) == 0 ? 1.0 : (max - min);
    return ChartScale(min - span * pad, max + span * pad);
  }

  /// The bottom of the plot, in the series' units.
  final double low;

  /// The top of the plot, in the series' units.
  final double high;

  /// Legacy's `yPad`.
  static const double padFraction = 0.18;

  /// Legacy's 3 px of air above and below the plotted range.
  static const double inset = 3;

  /// Where [value] sits in a plot [height] px tall.
  double y(double value, double height) =>
      height - inset - ((value - low) / (high - low)) * (height - inset * 2);
}

/// Draws [reference] across the plot in [scale], fading in with [progress].
///
/// [color] is the caller's quiet ink — see the library docstring on why it is
/// never a verdict token. The label sits just above the line at the left edge,
/// clamped inside the box so a reference near the top does not paint off it.
void paintChartReference(
  Canvas canvas,
  Size size,
  ChartReference reference, {
  required ChartScale scale,
  required Color color,
  required TextStyle labelStyle,
  required double progress,
}) {
  final y = scale.y(reference.value, size.height);
  if (!y.isFinite) {
    return;
  }
  final paint = Paint()
    ..color = revealed(color, progress)
    ..strokeWidth = 1;
  if (reference.isDashed) {
    for (var x = 0.0; x < size.width; x += _dash + _dashGap) {
      final end = (x + _dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  } else {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  final label = chartLabel(
    reference.label,
    labelStyle.copyWith(color: revealed(labelStyle.color ?? color, progress)),
  );
  final top = (y - label.height - 1).clamp(0.0, size.height - label.height);
  label.paint(canvas, Offset(0, top));
}

const double _dash = 3;
const double _dashGap = 3;
