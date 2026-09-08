/// The touch scrubber: a finger, a cursor, a bubble and a line of words.
///
/// ## Why the readout is a widget and the bubble is paint
///
/// They answer different questions. The bubble says *this sample* and has to be
/// at the cursor to mean anything, so it is painted, in the band
/// `chart_box.dart` reserves above the plot. The readout says *what you are
/// looking at, in a sentence* — the time, the value, the unit — and a sentence
/// under the chart is a sentence, not a mark on a plot; making it a widget means
/// it wraps, scales with the platform's text size, is read aloud in order, and
/// can carry a coloured key per series, which the linked chart needs.
///
/// The prototype has both (`<output class="chart-readout">`), and its resting
/// state is the instruction — *"Touch the chart to explore · bpm"*. That is
/// worth porting exactly: an interactive chart that does not say it is
/// interactive is a chart nobody touches.
///
/// ## The readout's height is fixed, and that is a layout claim
///
/// `.chart-readout { min-height: 22px }`. Reserved rather than intrinsic,
/// because the resting sentence and the scrubbed one are different lengths, and
/// a chart that grows a pixel when you touch it shoves every card below it.
/// [ChartScrub.readoutHeight] is also what a withheld chart adds to its empty
/// slot so the two states measure the same.
///
/// ## The linger, ported
///
/// A tap holds its reading for 1200 ms after the finger leaves
/// (`instrument_charts.dart:77`, and `h_area.dart` after it), because a tap that
/// clears on release shows the value only while a fingertip is covering it. A
/// drag still clears the moment it ends — nothing is covering anything then.
///
/// Touch state stays in this widget's `State` and that is correct: it is
/// per-instance and ephemeral, and losing it when the item scrolls out of a
/// `ListView.builder` is right, because nobody is still pointing at a chart that
/// is off screen. The *reveal* is the thing that must not live here, and it does
/// not — see `reveal_once.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/charts/v02/chart_box.dart';

/// Builds the chart for the sample under the finger, or null for none.
typedef ScrubbedChart = Widget Function(BuildContext context, int? index);

/// Builds the line under the chart for the sample under the finger.
typedef ScrubbedReadout = Widget Function(BuildContext context, int? index);

/// A chart, the touch area over it, and the readout under it.
class ChartScrub extends StatefulWidget {
  /// [sampleCount] is the series' length — the same one the painter indexes.
  const ChartScrub({
    required this.sampleCount,
    required this.height,
    required this.metrics,
    required this.chart,
    required this.readout,
    super.key,
  });

  /// How many samples the finger can land on.
  final int sampleCount;

  /// The chart's own height, excluding [readoutHeight] under it.
  final double height;

  /// The same spec the painter derives its plot from, so the finger and the
  /// trace agree about which sample is where. See [ChartMetrics].
  final ChartMetrics metrics;

  /// Draws the chart at the touched index.
  final ScrubbedChart chart;

  /// The line under it. Called with null when nothing is touched.
  final ScrubbedReadout readout;

  /// How long a tapped reading stays up after the finger leaves.
  static const Duration linger = Duration(milliseconds: 1200);

  /// `.chart-readout { min-height: 22px }`. See the library docstring.
  static const double readoutHeight = 22;

  @override
  State<ChartScrub> createState() => _ChartScrubState();
}

class _ChartScrubState extends State<ChartScrub> {
  int? _index;
  double _width = 1;

  void _scrub(double dx) {
    final box = widget.metrics.box(Size(_width, widget.height));
    final index = box.indexAt(dx, widget.sampleCount);
    if (index != _index) {
      setState(() => _index = index);
    }
  }

  void _clear() {
    if (mounted && _index != null) {
      setState(() => _index = null);
    }
  }

  void _clearAfterLinger() {
    unawaited(Future<void>.delayed(ChartScrub.linger, _clear));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _scrub(details.localPosition.dx),
        onTapUp: (_) => _clearAfterLinger(),
        onHorizontalDragStart: (details) => _scrub(details.localPosition.dx),
        onHorizontalDragUpdate: (details) => _scrub(details.localPosition.dx),
        onHorizontalDragEnd: (_) => _clear(),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) {
              _width = box.maxWidth;
              return widget.chart(context, _index);
            },
          ),
        ),
      ),
      SizedBox(
        height: ChartScrub.readoutHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: widget.readout(context, _index),
        ),
      ),
    ],
  );
}

/// The readout's default shape: one quiet centred line.
class ChartReadoutText extends StatelessWidget {
  /// Builds the line.
  const ChartReadoutText(this.text, {super.key});

  /// What it says.
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TypeScale.colourKey.copyWith(color: context.colors.ink3),
  );
}
