/// **The field is a backdrop, and the owner can stop it.**
///
/// `motion.css:9` — `.bio-hero .bio-art { position:absolute; inset:0;
/// width:100%; height:100%; opacity:1; z-index:-1 }` — over
/// `.bio-hero { overflow: clip; border-radius: 28px }`. Three claims, and each
/// one is asked of the painted geometry here: the field's box is the card's, it
/// is painted before the content, and it is cut to the rounded rect.
///
/// There is no fourth claim about a pause control here. One shipped for a while
/// and the owner asked for it back out. The field's three automatic stops are
/// `halo_motion_test.dart`'s, asserted there the only way they can be —
/// **identical particle coordinates**, never a flag. A field that keeps painting
/// somewhere new has not stopped, whatever it says about itself.
///
/// `today_hero_geometry_test.dart` asks the other half: what the card's height
/// is made of. The font and the widths are `_hero_probe.dart`'s.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/instruments/age_scale.dart';
import 'package:healthee/shared/v02/instruments/bio_halo.dart';
import 'package:healthee/shared/v02/instruments/halo_painter.dart';

import '../shared/instruments/_instrument_probe.dart';
import '_hero_probe.dart';
import '_today_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('the field is a backdrop', () {
    testWidgets('IT IS SIZED BY THE CARD, not the other way round', (
      tester,
    ) async {
      await pumpHeroAt(tester, store, 390);
      final hero = tester.getRect(find.byType(BioHero));
      // `inset: 0` inside the border: the field's box IS the card's, so it
      // cannot be the thing that decided how tall the card is.
      expect(tester.getRect(find.byType(BioHalo)), hero.deflate(hairline));
    });

    testWidgets('IT PAINTS BEHIND THE CONTENT — the stack order says so', (
      tester,
    ) async {
      await pumpHeroAt(tester, store, 390);
      // `RenderStack` paints its children in child order, so "first child" is
      // "painted first" is "behind". The figure is under the second.
      final stack = tester.renderObject<RenderStack>(
        find
            .descendant(of: find.byType(BioHero), matching: find.byType(Stack))
            .first,
      );
      final children = <RenderObject>[];
      stack.visitChildren(children.add);
      expect(children.length, 2);

      bool under(RenderObject ancestor, RenderObject box) {
        for (RenderObject? node = box.parent; node != null; node = node.parent) {
          if (identical(node, ancestor)) {
            return true;
          }
        }
        return false;
      }

      expect(
        under(children.first, tester.renderObject(find.byType(BioHalo))),
        isTrue,
        reason: 'the field is not the first thing painted',
      );
      expect(
        under(children.last, tester.renderObject(find.text('34.3'))),
        isTrue,
        reason: 'the figure is not painted after the field',
      );
    });

    testWidgets('IT IS CLIPPED TO THE 28px ROUNDED RECT', (tester) async {
      // `.bio-hero { overflow: clip }` over `border-radius: 28px`. Asked of the
      // clip path itself: a point 2px into the corner is outside a 28px radius,
      // and the same distance along the top edge is inside it.
      await pumpHeroAt(tester, store, 390);
      final clip = find
          .descendant(of: find.byType(BioHero), matching: find.byType(ClipPath))
          .first;
      final size = tester.getSize(clip);
      final path = tester.widget<ClipPath>(clip).clipper!.getClip(size);
      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(Offset(size.width / 2, 2)), isTrue);
    });

    testWidgets('ITS HOLE SITS OVER THE FIGURE, not over the sentence', (
      tester,
    ) async {
      // The still centre is where nothing is painted. Stretched across the whole
      // card, a field centred on the CARD puts its densest rim across the figure
      // and its hole over the caption and the ruler.
      await pumpHeroAt(tester, store, 390);
      paintedAt(tester, heroField);
      final painter =
          tester.widget<CustomPaint>(heroField).painter! as HaloPainter;
      final centre =
          tester.getRect(find.byType(BioHalo)).topLeft + painter.field!.centre;
      expect(tester.getRect(find.text('34.3')).contains(centre), isTrue);
    });
  });

  group('the content stays legible over the field', () {
    for (final theme in <String, ThemeData>{
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('${theme.key} — THE HOLE CLEARS THE NUMBER, END TO END', (
        tester,
      ) async {
        // Not a contrast argument about ink over ink: across the figure's whole
        // width, at the line it is read on, there is no field at all —
        // `halo_motion_test.dart` already proves nothing is ever painted inside
        // the still radius, and this puts the number inside it.
        //
        // The corners of the figure's line box are NOT claimed, and the
        // prototype does not claim them either: its own hole is 65 px in a
        // 258 px canvas, well inside the figure's box.
        await pumpHeroAt(tester, store, 390, theme: theme.value);
        paintedAt(tester, heroField);
        final field =
            (tester.widget<CustomPaint>(heroField).painter! as HaloPainter)
                .field!;
        final origin = tester.getRect(find.byType(BioHalo)).topLeft;
        final figure = tester.getRect(find.text('34.3'));
        for (final point in <Offset>[
          figure.centerLeft,
          figure.center,
          figure.centerRight,
        ]) {
          expect(
            (point - origin - field.centre).distance,
            lessThan(field.stillRadius),
            reason: 'the field reaches the line the number is read on',
          );
        }
      });

      testWidgets('${theme.key} — THE DENSE RIM CLEARS THE RULER', (
        tester,
      ) async {
        // The rim is where the field is brightest and thickest. It belongs
        // around the figure; the ruler's labels are read below it.
        await pumpHeroAt(tester, store, 390, theme: theme.value);
        paintedAt(tester, heroField);
        final field =
            (tester.widget<CustomPaint>(heroField).painter! as HaloPainter)
                .field!;
        final halo = tester.getRect(find.byType(BioHalo));
        expect(
          halo.top + field.centre.dy + field.ringRadius,
          lessThan(tester.getRect(find.byType(AgeScale)).top),
          reason: 'the rim runs across the age ruler',
        );
      });
    }
  });
}
