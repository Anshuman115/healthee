/// **BioHero, SectionHead, ColourKey, ContextBridge and IconTile, measured.**
///
/// The other half of the v02 primitive set; see `v02_primitives_test.dart` for
/// the method and `_v02_harness.dart` for the pump both halves share.
///
/// ## The numbers are LITERALS, and that is the whole point
///
/// These assertions used to read `Panel.padding` and `ContextBridge.ruleLeft` —
/// the very constants under test — so changing 18 to 14 changed the expectation
/// with it and the suite stayed green. Mutation testing caught two survivors on
/// exactly that shape. Every number below is now restated from the CSS by hand,
/// the same method `v02_tokens_test.dart` uses for the palette: a transcription
/// checked against a transcription.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/colour_key.dart';
import 'package:healthee/shared/v02/context_bridge.dart';
import 'package:healthee/shared/v02/icon_tile.dart';
import 'package:healthee/shared/v02/section_head.dart';

import '_v02_harness.dart';

void main() {
  group('BioHero — 28px radius, 22px padding, its own surface', () {
    testWidgets('the corner, the ground and the ink are the bio tokens', (
      tester,
    ) async {
      await pumpV02(
        tester,
        const BioHero(eyebrow: 'Biological age', value: '31.8'),
      );
      final decoration = decorationOf(
        tester,
        find.descendant(
          of: find.byType(BioHero),
          matching: find.byType(Container),
        ),
      );
      expect(decoration.color, kColors.bioBackground);
      expect(radiusOf(decoration), 28);
      expect(
        tester.widget<Text>(find.text('Biological age')).style!.color,
        kColors.bioInk,
      );
      expect(
        tester.widget<Text>(find.text('31.8')).style!.color,
        kColors.bioInk,
      );
    });

    testWidgets('the 88px figure sits 20 under the eyebrow, inset 22+1', (
      tester,
    ) async {
      await pumpV02(
        tester,
        const BioHero(eyebrow: 'Biological age', value: '31.8'),
      );
      final hero = tester.getRect(find.byType(BioHero));
      final eyebrow = tester.getRect(find.text('Biological age'));
      final value = tester.getRect(find.text('31.8'));
      expect(eyebrow.left - hero.left, 23);
      expect(eyebrow.top - hero.top, 23);
      expect(value.top - eyebrow.bottom, 20);
      final style = tester.widget<Text>(find.text('31.8')).style!;
      expect(style.fontSize, 88);
      expect(style.letterSpacing, -6);
      expect(style.height, 1);
    });

    testWidgets('the rule is FULL BLEED — it reaches both inner edges', (
      tester,
    ) async {
      await pumpV02(
        tester,
        const BioHero(
          eyebrow: 'Biological age',
          value: '31.8',
          caption: 'Two years under your chronological age.',
          stats: <BioStat>[BioStat('VO₂max', '40.6'), BioStat('RHR', '54')],
        ),
      );
      final hero = tester.getRect(find.byType(BioHero));
      final rule = tester.getRect(
        find.descendant(
          of: find.byType(BioHero),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(rule.height, 1);
      // 1 px in from each side: the border, which `overflow: clip` sits inside.
      expect(rule.left - hero.left, 1);
      expect(hero.right - rule.right, 1);

      final caption = tester.getRect(
        find.text('Two years under your chronological age.'),
      );
      final stat = tester.getRect(find.text('VO₂max'));
      expect(rule.top - caption.bottom, 18);
      expect(stat.top - rule.bottom, 14);
      expect(stat.left - hero.left, 23);
    });
  });

  group('SectionHead — 18px title, 12 above whatever follows', () {
    testWidgets('the title is 18px at 700 and the block ends 12 below it', (
      tester,
    ) async {
      await pumpV02(tester, const SectionHead(title: 'Last night'));
      final style = tester.widget<Text>(find.text('Last night')).style!;
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, -0.6);
      final head = tester.getRect(find.byType(SectionHead));
      final title = tester.getRect(find.text('Last night'));
      expect(head.bottom - title.bottom, 12);
    });
  });

  group('ColourKey — 6px dots, 5 to the label, 12 between entries', () {
    testWidgets('the dot is a 6px circle in the family', (tester) async {
      await pumpV02(
        tester,
        const ColourKey(<ColourKeyEntry>[ColourKeyEntry('Deep')]),
        tone: Tone.sleep,
      );
      final dot = tester.getRect(
        find.descendant(
          of: find.byType(ColourKey),
          matching: find.byType(Container),
        ),
      );
      expect(dot.width, 6);
      expect(dot.height, 6);
      final decoration = decorationOf(
        tester,
        find.descendant(
          of: find.byType(ColourKey),
          matching: find.byType(Container),
        ),
      );
      expect(decoration.color, kHues.sleep);
      expect(decoration.shape, BoxShape.circle);
      expect(tester.getRect(find.text('Deep')).left - dot.right, 5);
    });

    testWidgets('an explicit colour overrides the family — stage legends', (
      tester,
    ) async {
      await pumpV02(
        tester,
        ColourKey(<ColourKeyEntry>[
          ColourKeyEntry('Deep', colour: kHues.stageDeep),
        ]),
        tone: Tone.sleep,
      );
      final decoration = decorationOf(
        tester,
        find.descendant(
          of: find.byType(ColourKey),
          matching: find.byType(Container),
        ),
      );
      expect(decoration.color, kHues.stageDeep);
      expect(decoration.color, isNot(kHues.sleep));
    });
  });

  group('ContextBridge — the left rule at 8, its dot at 6/23', () {
    testWidgets('rule, dot and text sit where the CSS puts them', (
      tester,
    ) async {
      await pumpV02(
        tester,
        ContextBridge.text('Your resting heart rate followed it down.'),
        tone: Tone.heart,
      );
      final bridge = tester.getRect(find.byType(ContextBridge));
      final rule = tester.getRect(
        find.descendant(
          of: find.byType(ContextBridge),
          matching: find.byType(ColoredBox),
        ),
      );
      // `.first`: the Container that carries the bottom border builds a
      // DecoratedBox of its own, and the Stack's own child order puts the dot
      // ahead of it.
      final dot = tester.getRect(
        find
            .descendant(
              of: find.byType(ContextBridge),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final text = tester.getRect(
        find.text('Your resting heart rate followed it down.'),
      );

      // `margin: 0 8px`, then `::before { left: 8px; width: 1px }`.
      expect(rule.left - bridge.left, 8 + 8);
      expect(rule.width, 1);
      expect(rule.height, bridge.height);
      // `::after { left: 6px; top: 23px; width: 5px; height: 5px }`.
      expect(dot.left - bridge.left, 8 + 6);
      expect(dot.top - bridge.top, 23);
      expect(dot.width, 5);
      expect(dot.height, 5);
      // `padding: 14px 4px 14px 26px`.
      expect(
        text.left - bridge.left,
        8 + 26,
      );
      expect(text.top - bridge.top, 14);
      expect(
        tester.widget<Text>(
          find.text('Your resting heart rate followed it down.'),
        ).style!.fontSize,
        11,
      );
    });

    testWidgets('the dot takes the family, so the bridge names its subject', (
      tester,
    ) async {
      await pumpV02(
        tester,
        ContextBridge.text('Sleep debt grew.'),
        tone: Tone.sleep,
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(ContextBridge),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, kHues.sleep);
      expect(decoration.shape, BoxShape.circle);
    });
  });

  group('IconTile — 40 × 40 at radius 13, family on family-soft', () {
    testWidgets('the box, the corner and both colours', (tester) async {
      await pumpV02(tester, const IconTile(Icons.air), tone: Tone.oxygen, width: null);
      final rect = tester.getRect(find.byType(IconTile));
      expect(rect.width, 40);
      expect(rect.height, 40);
      final decoration = decorationOf(
        tester,
        find.descendant(
          of: find.byType(IconTile),
          matching: find.byType(Container),
        ),
      );
      expect(decoration.color, kHues.oxygenSoft);
      expect(radiusOf(decoration), 13);
      expect(tester.widget<Icon>(find.byIcon(Icons.air)).color, kHues.oxygen);
    });

    testWidgets('with no scope it takes fitness — richer.css :root', (
      tester,
    ) async {
      await pumpV02(tester, const IconTile(Icons.air), width: null);
      expect(tester.widget<Icon>(find.byIcon(Icons.air)).color, kHues.fitness);
    });
  });
}
