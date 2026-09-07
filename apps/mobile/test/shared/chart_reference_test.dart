/// A reference line is a CLAIM, and these are the four ways it lies quietly.
///
/// Owner, 2026-08-06, on the installed build: *"stress is named as AROUSAL,
/// heart rate is also looks wried, same as blood oxygen you just made it bad."*
/// Three of the four charts had shipped with their reference caption painted
/// INSIDE the plot, on top of the series, and two spent most of the plot on air.
///
/// ## Why this file exists at all
///
/// These four claims were asserted through legacy's vitals cards — `HrvTrendCard`,
/// `HeartRateDayCard`, `BloodOxygenCard`, `StressCard` — in
/// `vitals_labels_test.dart`, `vitals_marks_test.dart` and
/// `vitals_scales_test.dart`. The v02 redesign made all four cards unreachable
/// from `main.dart`, so those suites went with them.
///
/// **The defects did not.** `chart_reference.dart` is still drawn by five live
/// v02 painters and by `HArea`, which the diagnostics metric strip renders, so
/// every one of these can still come back. The assertions are ported here
/// against the primitive itself rather than through a card, which is where they
/// should have been: the card was never the thing under test.
///
/// Each of the four is broken on purpose in `test/mutations.sh`.
///
/// ## Why it is geometric and not textual
///
/// Every version of these defects renders. `findsOneWidget` passes for a label
/// lying across a line, `contains('RESTING')` passes, and a count of
/// `drawParagraph` calls passes for a label drawn perfectly in the wrong place —
/// the labels WERE being drawn, correctly, on top of the data. So both halves
/// are measured as rectangles and as paint order.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/charts/chart_reference.dart';
import 'package:healthee/shared/charts/h_area.dart';

import '_chart_probe.dart';

/// The heart-rate plot's height, as the diagnostics strip draws it.
const double _dayHeight = 52;

/// The share of its own plot a reading must own.
///
/// A display decision, written down rather than inlined. Below this the trace is
/// a flat line inside a mostly empty box, which is what the owner was looking at
/// — the symmetric padding this replaced gave the same day 51%.
const double _usableShare = 0.55;

/// The owner's own shape: a quiet day of 60–75 bpm over a resting rate of 56.
///
/// Not a made-up series. This is the day he was looking at when he said the
/// chart looked wrong, and it is the one where symmetric padding hands 49% of
/// the plot to empty space.
const List<double> _trace = <double>[60, 66, 72, 75, 68, 63, 70];
const double _resting = 56;

/// The chart the mutations are aimed at: a real reference, with a real caption.
Widget _chart({bool fill = true}) => HArea(
  _trace,
  color: const Color(0xFF1F6F54),
  progress: 1,
  height: _dayHeight,
  fill: fill,
  references: const <ChartReference>[
    ChartReference.personalBaseline(value: _resting, label: 'RESTING 56'),
  ],
);

void main() {
  group('the scale a reference is drawn in', () {
    test('A REFERENCE OUTSIDE THE DATA WIDENS THE PLOT, NOT ITS OWN EDGE', () {
      // The failure this exists for: a reference outside the data's own range
      // drawn in the data's own scale lands on the bottom edge, where it reads
      // as "you never went below your resting rate" — a false claim made
      // entirely by layout. `ChartScale.of(include:)` is the fix.
      final scale = ChartScale.of(_trace, include: const <double>[_resting]);
      final y = scale.y(_resting, _dayHeight);

      expect(y, lessThan(_dayHeight), reason: 'the line fell off the bottom');
      expect(y, greaterThan(0));
      expect(
        y,
        greaterThan(scale.y(_trace.reduce((a, b) => a < b ? a : b), _dayHeight)),
        reason: 'a resting rate below every hour must sit below every hour',
      );
      // And with no references at all the scale is unchanged, which is what
      // makes this extension safe for every chart that does not use it.
      expect(
        ChartScale.of(_trace).low,
        ChartScale.of(_trace, include: const <double>[]).low,
      );
    });

    test('THE READING STILL OWNS MOST OF ITS OWN BOX', () {
      // The padding is asymmetric on purpose. A reference below the data is a
      // straight line, not a peak that can be clipped, so padding it by the
      // data's own 18% spends the plot on nothing: on the owner's own day that
      // handed 49% of the height to empty space and the trace read as flat.
      final scale = ChartScale.of(_trace, include: const <double>[_resting]);
      final share = scale.share(
        _trace.reduce((a, b) => a < b ? a : b),
        _trace.reduce((a, b) => a > b ? a : b),
        _dayHeight,
      );

      expect(
        share,
        greaterThanOrEqualTo(_usableShare),
        reason:
            'the trace owns ${(share * 100).toStringAsFixed(1)}% of its plot — '
            'a chart about its padding rather than about the reading',
      );
    });
  });

  group('what the painter actually draws', () {
    testWidgets('THE REFERENCE SITS WHERE THE SHARED SCALE PUTS IT', (
      tester,
    ) async {
      await tester.pumpWidget(chartHost(_chart()));
      await tester.pumpAndSettle();

      final lines = <double>[
        for (final call in paintedBy(tester, find.byType(HArea)))
          if (call.invocation.memberName == #drawLine)
            (call.invocation.positionalArguments[0] as Offset).dy,
      ];
      expect(lines, hasLength(1), reason: 'one solid reference, no scrub');

      // The claim: the painter widened its OWN scale to hold the reference. A
      // painter that dropped `include:` still draws a line — one that lands
      // below every point, on the floor, reading as "you never went below your
      // resting rate". That version passes any "is it drawn" test ever written.
      expect(
        lines.single,
        closeTo(
          ChartScale.of(
            _trace,
            include: const <double>[_resting],
          ).y(_resting, _dayHeight),
          0.01,
        ),
      );
      expect(
        lines.single,
        lessThan(_dayHeight - ChartScale.inset),
        reason: 'the reference is clipping to the bottom edge',
      );
      expect(lines.single, greaterThan(ChartScale.inset));
    });

    testWidgets('IT IS PAINTED ON THE FILL, AND UNDER THE TRACE', (
      tester,
    ) async {
      // The other half of "looks wried", and it is invisible to every assertion
      // about WHAT was drawn: the reference painted first, so a grey hairline
      // sits under a 32% clay wash and comes out as brown sludge. Paint order is
      // the whole fix.
      await tester.pumpWidget(chartHost(_chart()));
      await tester.pumpAndSettle();

      final names = <Symbol>[
        for (final call in paintedBy(tester, find.byType(HArea)))
          call.invocation.memberName,
      ];
      final fill = names.indexOf(#drawPath);
      final reference = names.indexOf(#drawLine);
      final trace = names.lastIndexOf(#drawPath);

      expect(fill, isNonNegative);
      expect(reference, isNonNegative);
      expect(
        fill,
        lessThan(reference),
        reason: 'the fill is painted over the reference — grey under clay',
      );
      expect(
        reference,
        lessThan(trace),
        reason: 'and the reading still crosses over its own ground',
      );
    });

    testWidgets('NO CAPTION IS EVER INK IN THE PLOT', (tester) async {
      // THE defect the owner photographed. `YOUR 30-DAY NORMAL 53 MS` across the
      // HRV trace; `RESTING 56` in the same pixels as the hour captions. The
      // label was drawn CORRECTLY, in the wrong place, which is why nothing
      // short of geometry catches it.
      //
      // The structural half is asserted first because it fails more legibly: the
      // painter has no business laying out text at all. A caption is a widget
      // under the chart (`ChartReferenceCaption`); the only text a painter may
      // lay out is the scrub bubble, which floats above the box and only while a
      // finger is on it.
      await tester.pumpWidget(chartHost(_chart()));
      await tester.pumpAndSettle();

      final painted = paintedBy(tester, find.byType(HArea));
      final glyphs = glyphRectsOf(painted);
      final marks = markRectsOf(painted);

      expect(
        glyphs,
        isEmpty,
        reason: 'the reference painter laid out text inside the plot',
      );
      for (final glyph in glyphs) {
        for (final mark in marks) {
          expect(
            glyph.overlaps(mark),
            isFalse,
            reason:
                'a label at $glyph is painted over a data mark at $mark — this '
                'is exactly what shipped',
          );
        }
      }
    });
  });
}
