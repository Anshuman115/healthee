/// Probes for the v02 charts: pump one, then read the geometry it really drew.
///
/// `_chart_probe.dart` already replays a painter, but it sizes the replay from
/// the widget it was handed. A v02 chart is a `Column` — plot, readout, maybe a
/// caption — so replaying its painter at the Column's height would measure a
/// plot 22 px taller than the one on screen, and every geometric assertion below
/// would be about a chart nobody sees. So these size the replay from the
/// `CustomPaint` itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// `richer.css`: `#main { padding: 20px 16px }` on a 360 dp phone.
const double kChartWidth = 328;

/// Pumps [chart] under [tone], in dark (v02's default) or light.
Future<void> pumpChart(
  WidgetTester tester,
  Widget chart, {
  Tone tone = Tone.heart,
  bool dark = true,
  double width = kChartWidth,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ToneScope(tone: tone, child: chart),
        ),
      ),
    ),
  ),
);

/// The `CustomPaint` inside [chart].
Finder painterOf(Finder chart) =>
    find.descendant(of: chart, matching: find.byType(CustomPaint)).first;

/// The size the chart's painter is really laid out at.
Size paintSize(WidgetTester tester, Finder chart) =>
    tester.getSize(painterOf(chart));

/// Replays [chart]'s painter at the size it was really laid out to.
List<RecordedInvocation> paintedAt(WidgetTester tester, Finder chart) {
  final paint = tester.widget<CustomPaint>(painterOf(chart));
  final canvas = TestRecordingCanvas();
  paint.painter!.paint(canvas, paintSize(tester, chart));
  return canvas.invocations;
}

/// The painter itself, for reading a parameter such as `progress`.
T painterFor<T extends CustomPainter>(WidgetTester tester, Finder chart) =>
    tester.widget<CustomPaint>(painterOf(chart)).painter! as T;

/// Every straight line a painter drew, as its two endpoints.
///
/// Gridlines, reference lines and the scrub cursor. Kept apart from the marks
/// because a rule is structure, not a reading.
List<(Offset, Offset)> linesOf(List<RecordedInvocation> invocations) =>
    <(Offset, Offset)>[
      for (final call in invocations)
        if (call.invocation.memberName == #drawLine)
          (
            call.invocation.positionalArguments[0] as Offset,
            call.invocation.positionalArguments[1] as Offset,
          ),
    ];

/// Every rounded rect a painter drew, with the colour it was drawn in.
List<(Rect, Color)> columnsOf(List<RecordedInvocation> invocations) =>
    <(Rect, Color)>[
      for (final call in invocations)
        if (call.invocation.memberName == #drawRRect)
          (
            (call.invocation.positionalArguments[0] as RRect).outerRect,
            (call.invocation.positionalArguments[1] as Paint).color,
          ),
    ];

/// Whether [a] and [b] are at least [clearance] apart.
///
/// Non-overlap is not enough. A caption whose glyph shares an edge with a bar is
/// legible only by accident, and a chart that changes by one pixel would put
/// them on top of each other with no test failing.
bool clearsBy(Rect a, Rect b, double clearance) =>
    !a.inflate(clearance / 2).overlaps(b.inflate(clearance / 2));
