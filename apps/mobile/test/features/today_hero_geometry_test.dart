/// **The hero's height comes from its content, and from nothing else.**
///
/// The prototype's two `.bio-art` rules are both `position: absolute`
/// (`richer.css:83`, `motion.css:9`), so the field is sized **by** the card and
/// contributes nothing to it. What the card is tall enough for is therefore
/// entirely a question about its content — which is what this suite measures.
/// `today_hero_field_test.dart` asks the other half: what the field does once
/// the card has a size.
///
/// ## The design, measured
///
/// Served from `design/mobile-preview` and measured in a real browser at four
/// phone widths, `.bio-hero` is **512 / 548 / 574 / 578** px tall at
/// 320 / 360 / 390 / 414. Its tallest term by far is `.bio-display` — an
/// `aspect-ratio: 1` grid box capped at `max-width: 304px` — which is *content*,
/// laid out by the browser, with both canvases absolutely positioned inside and
/// around it.
///
/// Those four numbers are not asserted here, because this card's last block is
/// the contributions row rather than the prototype's: the model line and the
/// honesty caveat moved into the eyebrow's ⓘ, so they make no height at all —
/// which is exactly why the assertion below no longer names them. What IS
/// asserted is the
/// thing that makes the number — **the card's height is the sum of its content
/// blocks and the CSS gaps between them, and nothing else.** A field that drove
/// the height would break that sum by exactly the amount it drove it.
///
/// The font and the four widths are `_hero_probe.dart`'s, and its docstring says
/// why each matters.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/v02/bio_display.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';
import 'package:healthee/shared/v02/instruments/age_scale.dart';

import '../shared/instruments/_instrument_probe.dart';
import '_hero_probe.dart';
import '_today_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFigtree);
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('the card is as tall as its content, at every phone width', () {
    for (final width in kPhoneWidths) {
      testWidgets('$width — the height is the content stack, summed', (
        tester,
      ) async {
        await pumpHeroAt(tester, store, width);
        final hero = tester.getRect(find.byType(BioHero));

        double heightOf(Finder finder) => tester.getRect(finder).height;
        final caption = find.textContaining('chronological age of');
        // Neither the model line nor the caveat is drawn on the card any more,
        // so neither appears in this sum. If one came back, the card would be
        // taller than the sum and this test would say so.
        expect(find.byType(BioModelLabel), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BioHero),
            matching: find.byType(CaveatNote),
          ),
          findsNothing,
        );

        // Every gap is a literal restated from the CSS by hand — the method
        // `v02_layout_test.dart` records. Reading `BioHero.contextGap` here
        // would move the expectation with the constant under test.
        final expected =
            hairline + // border-top
            22 + // padding-top
            32 + // .bio-eyebrow, whose 32px control sets its height
            bioDisplaySide(hero.width - hairline * 2) + // .bio-display, square
            heightOf(caption) + // .age-context, margin-top reset by motion.css
            18 + // .age-context { margin-bottom: 18px }
            heightOf(find.byType(AgeScale)) +
            16 + // .bio-divider { margin-top: 16px }
            hairline + // the rule itself
            14 + // .bio-divider { padding-top: 14px }
            heightOf(find.byType(BioStatsRow)) +
            22 + // padding-bottom
            hairline; // border-bottom

        expect(
          hero.height,
          moreOrLessEquals(expected, epsilon: 0.5),
          reason:
              'the card is ${hero.height} tall but its content is $expected — '
              'something other than the content is making the height',
        );
      });

      testWidgets('$width — the square is min(content width, 304)', (
        tester,
      ) async {
        // `.bio-display { width:100%; max-width:304px; aspect-ratio:1 }`, inside
        // `.bio-hero { padding: 22px }` and its 1px border. This is the card's
        // tallest term, so it is the one that has to be right.
        await pumpHeroAt(tester, store, width);
        final hero = tester.getRect(find.byType(BioHero));
        final square = tester.getRect(
          find
              .descendant(
                of: find.byType(BioHero),
                matching: find.byType(AspectRatio),
              )
              .first,
        );
        final content = hero.width - hairline * 2 - 22 * 2;
        expect(square.width, content < 304 ? content : 304);
        expect(square.height, square.width);
        // And it starts directly under the eyebrow: `.age-value { margin: 0 }`.
        expect(square.top - hero.top, hairline + 22 + 32);
      });

      testWidgets('$width — the contributions and the ⓘ are INSIDE', (
        tester,
      ) async {
        // The complaint this suite exists for: a card taller than its own
        // content pushed both off the bottom of the screen. The ⓘ replaces the
        // model label here — it is now the thing carrying that sentence, and a
        // disclosure the owner cannot reach is the same failure as one printed
        // off the edge.
        await pumpHeroAt(tester, store, width);
        final hero = tester.getRect(find.byType(BioHero));
        final parts = <String, Finder>{
          'the contributions row': find.byType(BioStatsRow),
          'the eyebrow ⓘ': find.descendant(
            of: find.byType(BioHero),
            matching: find.byType(MetricInfoDot),
          ),
        };
        for (final part in parts.entries) {
          final rect = tester.getRect(part.value);
          expect(hero.contains(rect.topLeft), isTrue);
          expect(
            hero.contains(rect.bottomRight - const Offset(0.01, 0.01)),
            isTrue,
            reason: '${part.key} falls outside the card it belongs to',
          );
        }
      });
    }
  });

  testWidgets('THE EYEBROW ROW IS 32 EVEN WITH NO CONTROL IN IT', (
    tester,
  ) async {
    // `bioStillCentre` places the field's hole by arithmetic — padding, this
    // row, half the square — and the row is 32 because
    // `.bio-controls .motion-toggle` is. A centred hero drawn without a control
    // must still leave 32, or the hole slides up by the difference the moment
    // one is not there.
    await tester.pumpWidget(
      instrumentHost(
        const BioHero(
          eyebrow: 'Biological age',
          value: '31.8',
          unit: 'years',
          centred: true,
        ),
      ),
    );
    final hero = tester.getRect(find.byType(BioHero));
    final square = tester.getRect(
      find
          .descendant(
            of: find.byType(BioHero),
            matching: find.byType(AspectRatio),
          )
          .first,
    );
    expect(square.top - hero.top, hairline + 22 + 32);
  });
}
