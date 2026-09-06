/// The probes the five hero instruments are measured with.
///
/// `_chart_probe.dart` replays the FIRST `CustomPaint` under a finder, which is
/// right for a chart that is one painter and nothing else. Three of these
/// instruments are a painter plus a real `Text` (the rail's note) or sit inside a
/// hero, so the painter is addressed by its own key and replayed at the size
/// **that box** was laid out to — not the size of the column around it. Reading
/// the wrong size is how a chart passes a test at zero height, which this project
/// has shipped twice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// The phone's content width, as `_v02_harness.dart` measures it.
const double kInstrumentWidth = 328;

/// One instrument at the content width, in [tone], on v02's default dark theme.
Widget instrumentHost(
  Widget child, {
  Tone tone = Tone.fitness,
  double width = kInstrumentWidth,
  bool light = false,
}) => MaterialApp(
  theme: light ? AppTheme.light : AppTheme.dark,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: ToneScope(tone: tone, child: child),
      ),
    ),
  ),
);

/// Replays the painter of the `CustomPaint` at [finder], at its own laid-out size.
List<RecordedInvocation> paintedAt(WidgetTester tester, Finder finder) {
  final paint = tester.widget<CustomPaint>(finder);
  final canvas = TestRecordingCanvas();
  paint.painter!.paint(canvas, tester.getSize(finder));
  return canvas.invocations;
}

/// Every point drawn through `drawPoints`, flattened in draw order.
List<Offset> pointsOf(List<RecordedInvocation> invocations) => <Offset>[
  for (final call in invocations)
    if (call.invocation.memberName == #drawPoints)
      ...call.invocation.positionalArguments[1] as List<Offset>,
];

/// Every `drawCircle`, as its centre and radius.
List<({Offset at, double radius})> circlesOf(
  List<RecordedInvocation> invocations,
) => <({Offset at, double radius})>[
  for (final call in invocations)
    if (call.invocation.memberName == #drawCircle)
      (
        at: call.invocation.positionalArguments[0] as Offset,
        radius: call.invocation.positionalArguments[1] as double,
      ),
];

/// Every `drawLine`, as its two ends.
List<({Offset from, Offset to})> linesOf(List<RecordedInvocation> invocations) =>
    <({Offset from, Offset to})>[
      for (final call in invocations)
        if (call.invocation.memberName == #drawLine)
          (
            from: call.invocation.positionalArguments[0] as Offset,
            to: call.invocation.positionalArguments[1] as Offset,
          ),
    ];

/// Every `drawPath`, with the style it was painted in — a filled path and a
/// stroked one are different claims about the same geometry.
List<({Path path, PaintingStyle style})> pathsOf(
  List<RecordedInvocation> invocations,
) => <({Path path, PaintingStyle style})>[
  for (final call in invocations)
    if (call.invocation.memberName == #drawPath)
      (
        path: call.invocation.positionalArguments[0] as Path,
        style: (call.invocation.positionalArguments[1] as Paint).style,
      ),
];

/// Samples [path] at [count] points along its length.
List<Offset> samplePath(Path path, {int count = 24}) => <Offset>[
  for (final metric in path.computeMetrics())
    for (var i = 0; i <= count; i++)
      metric.getTangentForOffset(metric.length * i / count)!.position,
];
