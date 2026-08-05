/// Shared probes for the ported charts: replay a painter, read what it drew.
///
/// Split out of `legacy_charts_test.dart` when that file passed the 400-line
/// gate. The helpers are the interesting part and both chart suites need them,
/// so they live in one place rather than being copied (Standards §1).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/models/last_sleep.dart';
import 'package:healthee/data/models/sleep_history.dart';

/// The width every chart is laid out at.
const double hostWidth = 300;

/// One chart at a fixed width, in [theme].
Widget chartHost(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(
    body: Center(child: SizedBox(width: hostWidth, child: child)),
  ),
);

/// Replays the painter inside [finder] onto a recording canvas.
///
/// This is the whole point of the file: it captures the `drawRect`,
/// `drawRRect`, `drawLine`, `drawCircle` and `drawPath` calls the chart really
/// makes, at the size it was really laid out to. A presence check cannot see a
/// chart that painted nothing, or one laid out at zero height.
List<RecordedInvocation> paintedBy(WidgetTester tester, Finder finder) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: finder, matching: find.byType(CustomPaint)).first,
  );
  final size = tester.getSize(finder);
  final canvas = TestRecordingCanvas();
  paint.painter!.paint(canvas, size);
  return canvas.invocations;
}

/// Every rect a painter drew, from `drawRect` and `drawRRect` alike.
List<Rect> rectsOf(List<RecordedInvocation> invocations) => <Rect>[
  for (final call in invocations)
    if (call.invocation.memberName == #drawRect)
      call.invocation.positionalArguments[0] as Rect
    else if (call.invocation.memberName == #drawRRect)
      (call.invocation.positionalArguments[0] as RRect).outerRect,
];

/// Every colour a painter used, as packed ARGB.
///
/// Packed rather than compared as `Color`, and the reason is a real trap: a
/// `Paint` stores its colour as float32, so reading it back gives components
/// that differ from a `const Color(0xFFBF472E)` in the last bits. `==` fails
/// while `toString()` on both prints the identical four decimal places, which is
/// a failure nobody can read. `toARGB32()` quantises both sides the same way.
Set<int> coloursOf(List<RecordedInvocation> invocations) => <int>{
  for (final call in invocations)
    for (final argument in call.invocation.positionalArguments)
      if (argument is Paint) argument.color.toARGB32(),
};

/// How many times [member] was called.
int countOf(List<RecordedInvocation> invocations, Symbol member) => invocations
    .where((call) => call.invocation.memberName == member)
    .length;

/// Seven nights of ordinary sleep.
List<SleepNightSummary> week() => <SleepNightSummary>[
  for (var i = 0; i < 7; i++)
    SleepNightSummary(
      date: '2026-08-0${i + 1}',
      durationMin: 380 + i * 10,
      deepMin: 70,
      lightMin: 210 + i * 10,
      remMin: 80,
      awakeMin: 20,
      deviceScore: null,
    ),
];

/// One staged span, with the offsets the model requires.
SleepStageSpan span(String stage, double start, double minutes) => SleepStageSpan(
  stage: stage,
  startOffsetMin: start,
  endOffsetMin: start + minutes,
  durationMin: minutes,
);
