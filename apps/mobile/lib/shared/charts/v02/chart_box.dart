/// The plot, and the gutters around it. **Data lives in one; words live in the
/// others; they do not share pixels.**
///
/// ## Why this is a type and not four numbers in a painter
///
/// `chart_reference.dart` records what happened the last time a label and a data
/// mark were laid out by the same free hand: three charts shipped with the
/// caption lying across the trace — *"heart rate is also looks wried, same as
/// blood oxygen you just made it bad"* — and both the words and the reading
/// became unreadable, which is strictly worse than the bare chart.
///
/// The fix there was a rule ("a label is not ink in the plot"). A rule is only
/// as good as the next painter's memory of it, so here it is **geometry**: a
/// painter that draws its series inside [plot] and its words inside [values] or
/// [captions] cannot produce an overlap, because those rectangles are disjoint
/// by construction. `test/shared/v02_chart_foundation_test.dart` asserts both
/// halves — that the rects stay apart, and that every glyph a real chart paints
/// clears every mark it paints by [clearance].
///
/// ## The bubble band
///
/// The scrub bubble is the one mark that used to be allowed over the data: the
/// ported `HArea` floats it above the plot but *outside the widget's own box*,
/// at a negative y, which works only as long as no ancestor clips. Here it gets
/// a reserved band of its own at the top of the widget. It costs 22 px of a
/// 170 px chart and it means the value you are pointing at is never hidden by
/// the label naming it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How much room a chart reserves around its plot.
///
/// A `const` spec rather than arguments to a painter, because the touch handler
/// and the painter must derive the *same* plot rectangle from the same numbers —
/// a scrubber that maps a finger against a different rectangle than the one the
/// series was drawn in reports the wrong sample and looks exactly right.
@immutable
class ChartMetrics {
  /// Builds a spec. Prefer the named constants below.
  const ChartMetrics({
    this.valueGutter = gutterWidth,
    this.captionStrip = 15,
    this.bubbleBand = 0,
    this.padX = 4,
    this.padRight = 4,
    this.padTop = 6,
  });

  /// The full-dress chart: value labels on the right, captions underneath, and
  /// a band at the top for the scrub bubble.
  static const ChartMetrics series = ChartMetrics(
    bubbleBand: 22,
    padRight: 8,
  );

  /// A framed chart nobody can scrub — bars, buckets, a linked pane.
  static const ChartMetrics framed = ChartMetrics();

  /// Room for a five-character tick label at 10 px.
  static const double gutterWidth = 34;

  /// No chrome at all: the plot is the whole box. The sparkline's spec.
  static const ChartMetrics bare = ChartMetrics(
    valueGutter: 0,
    captionStrip: 0,
    padX: 5,
    padTop: 4,
  );

  /// The air a glyph must leave around the plot. Asserted, not assumed.
  static const double clearance = 2;

  /// The right-hand strip the tick labels are written in.
  final double valueGutter;

  /// The strip under the plot the edge captions are written in.
  final double captionStrip;

  /// The band above the plot the scrub bubble occupies. Zero when there is no
  /// scrubber, because reserving it would be 22 px of nothing.
  final double bubbleBand;

  /// Horizontal air inside the plot, so a round cap at either end is not half
  /// clipped by the widget's edge.
  final double padX;

  /// Air between the plot's right edge and the gutter the labels start in.
  ///
  /// It exists because the last-point dot is centred ON the last sample and is
  /// 5.3 px wide including its ring, so a plot that ran right up to the gutter
  /// would poke that ring into the top tick's label. Eight px for a chart with a
  /// dot, four for one without: the clearance the tests assert is exactly this
  /// number minus the dot, and it is a number rather than a hope.
  final double padRight;

  /// Air between the bubble band and the top rule.
  final double padTop;

  /// The rectangles for a widget laid out at [size].
  ///
  /// With a gutter, the plot stops where the gutter starts and the gutter is
  /// the air a last-point dot needs. **Without** one — the sparkline — the plot
  /// is inset by [padX] on the right as well, because a dot centred exactly on
  /// the widget's edge is a half dot.
  ChartBox box(Size size) {
    final gutterLeft = size.width - valueGutter;
    final plotRight = valueGutter > 0
        ? gutterLeft - padRight
        : size.width - padX;
    final plotTop = bubbleBand + padTop;
    final plotBottom = size.height - captionStrip;
    return ChartBox(
      plot: Rect.fromLTRB(padX, plotTop, plotRight, plotBottom),
      values: Rect.fromLTRB(gutterLeft, plotTop, size.width, plotBottom),
      captions: Rect.fromLTRB(0, plotBottom, size.width, size.height),
      bubble: Rect.fromLTRB(0, 0, size.width, bubbleBand),
    );
  }
}

/// The four disjoint rectangles a chart is allowed to draw in.
@immutable
class ChartBox {
  /// Built by [ChartMetrics.box].
  const ChartBox({
    required this.plot,
    required this.values,
    required this.captions,
    required this.bubble,
  });

  /// **The only rectangle a series may be drawn in.** Gridlines and reference
  /// lines span it; the curve, the bars and the dots are inside it.
  final Rect plot;

  /// The right-hand gutter, for tick labels. Never contains a data mark.
  final Rect values;

  /// The strip under the plot, for the two edge captions.
  final Rect captions;

  /// The band above the plot, for the scrub bubble.
  final Rect bubble;

  /// Whether there is enough room to draw anything at all.
  ///
  /// A chart in a collapsed slot paints nothing rather than painting a series
  /// one pixel tall: two charts on this project shipped at zero height and the
  /// tests did not notice, because they asked whether the widget existed.
  bool get isDrawable => plot.width > 1 && plot.height > 1;

  /// Where the sample at [index] of [count] sits horizontally.
  double x(int index, int count) => count < 2
      ? plot.center.dx
      : plot.left + (index / (count - 1)) * plot.width;

  /// The same four rects, moved down by [dy].
  ///
  /// The linked chart's two panes are laid out as lanes of one canvas and
  /// painted in **absolute** coordinates rather than under a `canvas.translate`.
  /// That is a testability decision with teeth: a recorded canvas replays the
  /// translate as an invocation, so a geometric assertion over what was drawn
  /// would be comparing the top pane's rects with the bottom pane's
  /// un-transformed ones and calling the result an overlap.
  ChartBox shift(double dy) => ChartBox(
    plot: plot.translate(0, dy),
    values: values.translate(0, dy),
    captions: captions.translate(0, dy),
    bubble: bubble.translate(0, dy),
  );

  /// Which sample [dx] is nearest, or null when there is nothing to point at.
  ///
  /// The inverse of [x], and it lives beside it on purpose — see the note on
  /// [ChartMetrics] about a scrubber and a painter disagreeing.
  int? indexAt(double dx, int count) {
    if (count < 1 || plot.width <= 0) {
      return null;
    }
    final fraction = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (fraction * (count - 1)).round();
  }
}
