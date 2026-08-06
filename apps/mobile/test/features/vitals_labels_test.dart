/// NO LABEL SITS ON THE DATA — the defect the owner photographed, asserted.
///
/// Owner, 2026-08-06, on the installed build: *"stress is named as AROUSAL,
/// heart rate is also looks wried, same as blood oxygen you just made it bad."*
/// Three of the four charts had shipped with their reference caption painted
/// INSIDE the plot, on top of the series:
///
///   * HRV — `YOUR 30-DAY NORMAL 53 MS` across the trace, both illegible;
///   * heart rate — `RESTING 56` in the same pixels as the hour captions;
///   * blood oxygen — a 55-character sentence straight through the nights.
///
/// A reference LINE may be drawn in the plot. Its label may not sit on the data.
/// The fix moved every caption out of the painter and into a widget under the
/// chart (`chart_reference.dart`), and this suite is what stops it coming back.
///
/// ## Why it is geometric and not textual
///
/// Every version of this defect renders. `findsOneWidget` passes for a label
/// lying across a line, a `contains('RESTING')` passes, and a count of
/// `drawParagraph` calls passes for a label drawn perfectly in the wrong place —
/// the labels WERE being drawn, correctly, on top of the data. So both halves
/// are measured as rectangles:
///
///   * on the canvas — no painted glyph may overlap a painted data mark, and no
///     glyph may overlap another glyph;
///   * in the layout — no `Text` in the card may overlap the chart's own box, or
///     any other `Text`.
///
/// Both themes, all four cards, because a caption that clears the plot in light
/// and not in dark is a caption that clears the plot by accident.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';

import '../shared/_chart_probe.dart';
import '_vitals_probe.dart';

void main() {
  final themes = <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  };

  group('a reference label is never ink in the plot', () {
    for (final theme in themes.entries) {
      for (final card in vitalsCards()) {
        testWidgets('${theme.key} · ${card.name} — NOTHING IS PAINTED OVER', (
          tester,
        ) async {
          await tester.pumpWidget(chartHost(card.build(), theme: theme.value));
          await tester.pumpAndSettle();

          final painted = paintedBy(tester, card.chart);
          final glyphs = glyphRectsOf(painted);
          final marks = markRectsOf(painted);

          for (final glyph in glyphs) {
            for (final mark in marks) {
              expect(
                glyph.overlaps(mark),
                isFalse,
                reason:
                    '${card.name}: a label at $glyph is painted over a data '
                    'mark at $mark — this is exactly what shipped',
              );
            }
            for (final other in glyphs) {
              if (identical(glyph, other)) {
                continue;
              }
              expect(
                glyph.overlaps(other),
                isFalse,
                reason: '${card.name}: two labels at $glyph and $other collide',
              );
            }
          }
          // And the structural half of the same claim: the painter has no
          // business laying out text at all now. It fails earlier and more
          // legibly than the overlap loop when someone puts a caption back.
          expect(
            glyphs,
            isEmpty,
            reason:
                '${card.name} painted text into its plot. A reference caption '
                'is a widget under the chart (ChartReferenceCaption); the only '
                'text a painter may lay out is the scrub bubble, which floats '
                'above the box and only while a finger is on it.',
          );
        });

        testWidgets(
          '${theme.key} · ${card.name} — NO CAPTION LIES ON THE CHART',
          (tester) async {
            final widget = card.build();
            await tester.pumpWidget(chartHost(widget, theme: theme.value));
            await tester.pumpAndSettle();

            final cardFinder = find.byWidget(widget);
            final plot = tester.getRect(card.chart);
            final labels = textRectsOf(tester, cardFinder);

            expect(
              labels,
              isNotEmpty,
              reason: 'a card with no text at all would pass this vacuously',
            );
            for (final label in labels) {
              expect(
                label.overlaps(plot),
                isFalse,
                reason:
                    '${card.name}: a caption at $label is laid out inside the '
                    'plot at $plot',
              );
            }
            for (var i = 0; i < labels.length; i++) {
              for (var j = i + 1; j < labels.length; j++) {
                expect(
                  labels[i].overlaps(labels[j]),
                  isFalse,
                  reason:
                      '${card.name}: ${labels[i]} and ${labels[j]} occupy the '
                      'same pixels — one of the two cannot be read',
                );
              }
            }
          },
        );
      }
    }
  });

  group('the reference is not washed out by the fill', () {
    testWidgets('THE HEART-RATE LINE IS PAINTED ON THE FILL, UNDER THE TRACE', (
      tester,
    ) async {
      // The other half of "looks wried": the reference used to be painted
      // first, so a grey hairline sat under a 32% clay wash and came out as the
      // brown sludge the owner reported. Paint order is the whole fix, and it
      // is invisible to every assertion about WHAT was drawn.
      final card = vitalsCards().firstWhere((c) => c.name == 'heart rate');
      await tester.pumpWidget(chartHost(card.build()));
      await tester.pumpAndSettle();

      final names = <Symbol>[
        for (final call in paintedBy(tester, card.chart))
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
  });

  group('the caption still says what the line is', () {
    // Moving the words must not lose them: a line nobody can name is a line
    // nobody can read, and it would pass every geometric assertion above.
    testWidgets('HRV names the owner’s own 30-day normal', (tester) async {
      final card = vitalsCards().firstWhere((c) => c.name == 'HRV');
      final widget = card.build();
      await tester.pumpWidget(chartHost(widget));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, find.byWidget(widget)).join(' · ').toUpperCase(),
        contains('30-DAY NORMAL 45 MS'),
      );
    });

    testWidgets('heart rate names the resting rate the line sits at', (
      tester,
    ) async {
      final card = vitalsCards().firstWhere((c) => c.name == 'heart rate');
      final widget = card.build();
      await tester.pumpWidget(chartHost(widget));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, find.byWidget(widget)).join(' · ').toUpperCase(),
        contains('RESTING 55 BPM'),
      );
    });

    testWidgets('blood oxygen still calls 92% a convention', (tester) async {
      final card = vitalsCards().firstWhere((c) => c.name == 'blood oxygen');
      final widget = card.build();
      await tester.pumpWidget(chartHost(widget));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, find.byWidget(widget)).join(' · ').toLowerCase(),
        contains('convention'),
      );
    });
  });
}
