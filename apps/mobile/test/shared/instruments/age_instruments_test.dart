/// **The two age instruments, measured.** Every assertion is a coordinate.
///
/// The one this file exists for is the exclusion. `README.md` reconciles the
/// sample as `36 - 1.7 fitness + 0.0 sleep = 34.3`, with regularity *excluded*,
/// and those last two terms look identical to a careless bar chart: a measured
/// zero and an exclusion both have "no size". They are opposite claims — one
/// says the lever was computed and did nothing, the other says it could not be
/// computed at all — so the tests below require the zero to draw a stub and the
/// exclusion to draw **no bar of any height**, and `mutations.sh` breaks exactly
/// that line to prove the requirement is load-bearing.
///
/// Column positions are asserted as relations rather than pixels, because the
/// right gutter is as wide as the axis label the text engine measured. The
/// numbers that ARE absolute — the stub's 3 px, the reveal's anchor, the ruler's
/// 33 ticks — are restated from the prototype by hand.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/shared/v02/instruments/age_scale.dart';
import 'package:healthee/shared/v02/instruments/age_waterfall.dart';

import '../_chart_probe.dart';
import '_instrument_probe.dart';

/// The prototype's sample: 36 - 1.7 + 0.0 = 34.3, regularity excluded.
const List<AgeTerm> kSampleTerms = <AgeTerm>[
  AgeTerm.measured('Fitness', -1.7, tone: Tone.fitness),
  AgeTerm.measured('Sleep', 0, tone: Tone.sleep),
  AgeTerm.excluded('Regularity', tone: Tone.sleep),
];

Finder get _scale => find.byKey(AgeScale.plotKey);
Finder get _ladder => find.byKey(AgeWaterfall.plotKey);

/// The bars, left to right. Nothing else in this instrument is a data mark.
List<Rect> bars(WidgetTester tester) =>
    markRectsOf(paintedAt(tester, _ladder))
      ..sort((a, b) => a.left.compareTo(b.left));

void main() {
  group('the age ruler', () {
    testWidgets('draws 33 ticks, one full-height marker and one dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeScale(estimate: 34.3, chronologicalAge: 36),
        ),
      );
      final painted = paintedAt(tester, _scale);
      final lines = linesOf(painted);
      final marker = lines.where((line) => line.from.dy == 0).toList();

      expect(lines.length, 34, reason: '33 ticks and the estimate marker');
      expect(marker.length, 1);
      // x = 16 + (34.3 - 28) / 16 * 308, on a 340-wide viewBox scaled to 328.
      expect(marker.single.from.dx, closeTo(132.4, 0.5));
      expect(marker.single.to.dy, 31);

      final dots = circlesOf(painted);
      expect(dots.length, 1);
      expect(dots.single.radius, 3);
      expect(dots.single.at.dy, 18);
      expect(
        dots.single.at.dx,
        greaterThan(marker.single.from.dx),
        reason: 'the owner reads younger than he is, so the dot is to the right',
      );
      expect(tester.getSize(_scale).height, 52);
    });

    testWidgets('A VALUE OFF THE RULER DRAWS NOTHING AND KEEPS THE SLOT', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeScale(estimate: 52, chronologicalAge: null),
        ),
      );
      final painted = paintedAt(tester, _scale);

      expect(
        linesOf(painted).length,
        33,
        reason: 'the ticks stay; a clamped marker would be a fabrication',
      );
      expect(circlesOf(painted), isEmpty);
      expect(tester.getSize(_scale).height, 52);
    });
  });

  group('the age waterfall', () {
    testWidgets('THE EXCLUDED TERM DRAWS NO BAR, and the slot stays', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeWaterfall(
            chronologicalAge: 36,
            estimate: 34.3,
            terms: kSampleTerms,
          ),
        ),
      );
      final drawn = bars(tester);

      expect(
        drawn.length,
        4,
        reason: 'five columns, and the excluded one draws no mark at all',
      );
      final ordinaryGap = drawn[1].left - drawn[0].right;
      final skippedGap = drawn[3].left - drawn[2].right;
      expect(
        skippedGap,
        greaterThan(ordinaryGap * 2),
        reason: 'a whole column was skipped, not drawn at zero height',
      );

      final labels = glyphRectsOf(paintedAt(tester, _ladder))
          .where(
            (rect) =>
                rect.center.dx > drawn[2].right &&
                rect.center.dx < drawn[3].left,
          )
          .toList();
      expect(
        labels.length,
        2,
        reason: 'the empty column says "excluded" AND keeps its name',
      );
    });

    testWidgets('a MEASURED zero still draws a stub, and it is 3px', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeWaterfall(
            chronologicalAge: 36,
            estimate: 34.3,
            terms: kSampleTerms,
          ),
        ),
      );
      expect(bars(tester)[2].height, closeTo(3, 0.01));
    });

    testWidgets('THE ARITHMETIC RECONCILES: the ladder lands on the estimate', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeWaterfall(
            chronologicalAge: 36,
            estimate: 34.3,
            terms: kSampleTerms,
          ),
        ),
      );
      final drawn = bars(tester);
      final painted = paintedAt(tester, _ladder);
      final connector = linesOf(painted)
          .where(
            (line) =>
                line.from.dx > drawn[2].right && line.to.dx <= drawn[3].left + 1,
          )
          .toList();

      expect(connector, isNotEmpty);
      expect(
        drawn[1].top,
        closeTo(drawn[0].top, 0.5),
        reason: 'the first step starts at the level the actual age reached',
      );
      expect(
        drawn[3].top,
        closeTo(drawn[1].bottom, 0.5),
        reason: '36 - 1.7 + 0.0 arrives exactly at 34.3',
      );
      expect(
        connector.any((line) => (line.from.dy - drawn[3].top).abs() < 0.5),
        isTrue,
        reason: 'the ladder is carried across at the level it reached',
      );
    });

    testWidgets('A LADDER THAT DOES NOT RECONCILE IS NOT SNAPPED SHUT', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeWaterfall(
            chronologicalAge: 36,
            estimate: 30,
            terms: kSampleTerms,
          ),
        ),
      );
      final drawn = bars(tester);
      expect(
        (drawn[3].top - drawn[1].bottom).abs(),
        greaterThan(10),
        reason: 'the gap is the disagreement, and it stays visible',
      );
    });

    testWidgets('a missing term draws nothing and keeps only its name', (
      tester,
    ) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeWaterfall(
            chronologicalAge: 36,
            estimate: 34.3,
            terms: <AgeTerm>[
              AgeTerm.measured('Fitness', -1.7, tone: Tone.fitness),
              AgeTerm.measured('Sleep', 0, tone: Tone.sleep),
              AgeTerm.missing('Regularity', tone: Tone.sleep),
            ],
          ),
        ),
      );
      final drawn = bars(tester);
      expect(drawn.length, 4);
      final labels = glyphRectsOf(paintedAt(tester, _ladder)).where(
        (rect) =>
            rect.center.dx > drawn[2].right && rect.center.dx < drawn[3].left,
      );
      expect(
        labels.length,
        1,
        reason: 'a missing term is not an excluded one and says nothing',
      );
      expect(tester.getSize(_ladder).height, AgeWaterfall.defaultHeight);
    });

    testWidgets('at progress 0 the bars have no height yet', (tester) async {
      await tester.pumpWidget(
        instrumentHost(
          const AgeWaterfall(
            chronologicalAge: 36,
            estimate: 34.3,
            terms: kSampleTerms,
            progress: 0,
          ),
        ),
      );
      for (final bar in bars(tester)) {
        expect(bar.height, closeTo(0, 0.01));
      }
    });
  });
}
