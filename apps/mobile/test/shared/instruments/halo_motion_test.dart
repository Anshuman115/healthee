/// **The halo stops.** Three ways, and each one is asserted by the halo's
/// geometry not changing — never by reading back a flag.
///
/// A flag test would have passed against every version of this widget that set
/// `_running = false` and kept the ticker scheduling a frame every vsync, which
/// is precisely the battery cost the pause exists to avoid. So each test here
/// replays the painter before and after, and requires the marks to be **at the
/// same coordinates**: a halo that is still drawing is a halo that has not
/// stopped, whatever it says about itself.
///
/// The last test is the honesty one: the age figure beside a demonstrably moving
/// halo does not move, resize or change by a pixel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/instruments/bio_halo.dart';
import 'package:healthee/shared/v02/instruments/halo_painter.dart';

import '_instrument_probe.dart';

/// The `.bio-art` box the halo is drawn in.
const Size kHaloBox = Size(300, 230);

Finder get _plot =>
    find.descendant(of: find.byType(BioHalo), matching: find.byType(CustomPaint)).first;

/// Pumps a halo on its own and returns the frame counter it increments.
Future<int Function()> pumpHalo(WidgetTester tester) async {
  var frames = 0;
  await tester.pumpWidget(
    instrumentHost(
      SizedBox.fromSize(
        size: kHaloBox,
        child: BioHalo(onFrame: () => frames++),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return () => frames;
}

/// Where every particle is right now.
List<Offset> marks(WidgetTester tester) => pointsOf(paintedAt(tester, _plot));

void main() {
  testWidgets('on screen, the halo advances and its particles move', (
    tester,
  ) async {
    final frames = await pumpHalo(tester);
    final first = marks(tester);
    expect(first, isNotEmpty, reason: 'the halo painted particles at all');

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(frames(), greaterThan(0));
    expect(
      marks(tester),
      isNot(equals(first)),
      reason: 'a running halo paints its particles somewhere new',
    );
  });

  testWidgets('BACKGROUNDED, IT STOPS — the marks do not move again', (
    tester,
  ) async {
    final frames = await pumpHalo(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final before = frames();
    final frozen = marks(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(frames(), before, reason: 'no frame was advanced');
    expect(marks(tester), frozen, reason: 'and nothing moved');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(frames(), greaterThan(before), reason: 'and it comes back');
  });

  testWidgets('OFFSCREEN, IT STOPS — and wakes on the way back', (
    tester,
  ) async {
    var frames = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: <Widget>[
                SizedBox.fromSize(
                  size: kHaloBox,
                  child: BioHalo(onFrame: () => frames++),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(frames, greaterThan(0), reason: 'it ran while it was visible');

    controller.jumpTo(1500);
    await tester.pump(const Duration(milliseconds: 100));
    final away = frames;
    final frozen = marks(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(frames, away, reason: 'scrolled away, it advanced no frame');
    expect(marks(tester), frozen);

    controller.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(frames, greaterThan(away), reason: 'scrolled back, it resumes');
  });

  testWidgets('PUSHED OFFSCREEN WITHOUT A SCROLL, IT STOPS', (tester) async {
    // Nothing here notifies anybody: no scroll position changes, no dependency
    // moves, the widget is not even rebuilt with new arguments. The only thing
    // that can notice is the frame check inside the tick, which is why this
    // test exists beside the scrolling one.
    var frames = 0;
    Widget host(double above) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Stack(
          children: <Widget>[
            Positioned(
              top: above,
              left: 0,
              child: SizedBox.fromSize(
                size: kHaloBox,
                child: BioHalo(onFrame: () => frames++),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(host(0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(frames, greaterThan(0));

    await tester.pumpWidget(host(700));
    await tester.pump(const Duration(milliseconds: 100));
    final away = frames;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(frames, away, reason: 'off the screen is off the clock');
  });

  testWidgets('UNDER REDUCED MOTION IT NEVER STARTS, and still paints once', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final frames = await pumpHalo(tester);
    final first = marks(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(frames(), 0, reason: 'the system setting is not a suggestion');
    expect(first, isNotEmpty, reason: 'the field is still drawn, just still');
    expect(marks(tester), first);
  });

  testWidgets('nothing is ever painted inside the still centre', (
    tester,
  ) async {
    await pumpHalo(tester);
    for (var step = 0; step < 6; step++) {
      await tester.pump(const Duration(milliseconds: 120));
      final invocations = paintedAt(tester, _plot);
      final painter = tester.widget<CustomPaint>(_plot).painter! as HaloPainter;
      final field = painter.field!;
      final still = field.stillRadius;
      expect(still, greaterThan(0));

      for (final point in pointsOf(invocations)) {
        expect(
          (point - field.centre).distance,
          greaterThanOrEqualTo(still),
          reason: 'a particle entered the still centre',
        );
      }
      for (final drawn in pathsOf(invocations)) {
        if (drawn.style == PaintingStyle.fill) {
          expect(
            drawn.path.contains(field.centre),
            isFalse,
            reason: 'a filled shape covered the figure',
          );
          continue;
        }
        for (final point in samplePath(drawn.path)) {
          expect((point - field.centre).distance, greaterThanOrEqualTo(still));
        }
      }
    }
  });

  testWidgets('THE AGE FIGURE NEVER MOVES while the halo does', (tester) async {
    var frames = 0;
    await tester.pumpWidget(
      instrumentHost(
        BioHero(
          eyebrow: 'Biological age',
          value: '34.3',
          unit: 'years',
          art: BioHalo(onFrame: () => frames++),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final figure = tester.getRect(find.text('34.3'));

    for (var step = 0; step < 5; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.text('34.3')),
        figure,
        reason: 'the measurement does not animate; the halo does',
      );
    }
    expect(frames, greaterThan(0), reason: 'the halo really was moving');
  });
}
