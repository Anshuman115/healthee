/// The halo's glint is `--halo-warm`, and it is amber on the canvas.
///
/// `motion.css` gives the prototype three halo inks and the third is warm:
/// `--halo-warm: oklch(88% .13 86)`. It shipped for a while as a *brightness*
/// event instead — `bioGlow` lifted toward `bioInk` — on the reasoning that the
/// only amber in the v02 palette is the `movement` family, and putting the steps
/// colour inside the biological-age card would import an identity the card is
/// not about. The reasoning was right and the conclusion was wrong: the answer
/// is a halo role of its own, which `palette.dart` now holds.
///
/// Two assertions, because the first alone is not enough. The ink set can carry
/// the right colour while the painter draws every particle in `core` — the
/// glint flag is per particle and the branch that reads it is one line — so the
/// second test rasterises the field and looks for the amber.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/palette.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/v02/instruments/halo_painter.dart';

/// `--halo-warm`, as `richer.css`'s `oklch(88% .13 86)` lands in sRGB.
const Color kHaloWarm = Color(0xFFFED16B);

/// The prototype's own art box, `BioHero.artRect`.
const Size _box = Size(300, 230);

/// Rasterises the halo on its own ground and returns the RGBA bytes.
Future<ui.Image> _render(HealtheeColors colors) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & _box);
  canvas.drawRect(
    Offset.zero & _box,
    Paint()..color = colors.bioBackground,
  );
  final clock = ValueNotifier<double>(4);
  HaloPainter(
    clock: clock,
    ink: HaloInk.of(colors),
    alignment: Alignment.center,
  ).paint(canvas, _box);
  clock.dispose();
  return recorder.endRecording().toImage(
    _box.width.round(),
    _box.height.round(),
  );
}

/// How many pixels are unmistakably warm — red well ahead of blue.
///
/// Nothing else on this canvas can produce one. The ground is `#132419`
/// (r 19, b 25), `bioGlow` is `#2D8C53` (r 45, b 83) and `bioLine` is `#57AE74`
/// (r 87, b 116): every ink but the glint has MORE blue than red, and the
/// blending only ever adds them together. So a pixel with red ahead of blue is
/// amber that was painted, not amber that was inferred.
Future<int> _warmPixels(HealtheeColors colors) async {
  final image = await _render(colors);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final bytes = data!.buffer.asUint8List();
  var warm = 0;
  for (var i = 0; i + 3 < bytes.length; i += 4) {
    if (bytes[i] - bytes[i + 2] > 20) {
      warm++;
    }
  }
  return warm;
}

void main() {
  test('THE GLINT IS --halo-warm, IN BOTH THEMES', () {
    // The prototype declares it once, outside either theme block, on a halo
    // surface it forces dark in both. So there is one value here too, and a
    // theme-dependent glint would be inventing a design decision.
    expect(HaloInk.of(const HealtheeColors.light()).glint, kHaloWarm);
    expect(HaloInk.of(const HealtheeColors.dark()).glint, kHaloWarm);
    expect(const HealtheeColors.light().haloWarm, kHaloWarm);
    expect(const HealtheeColors.dark().haloWarm, kHaloWarm);
  });

  test('AND IT IS NOT THE MOVEMENT FAMILY, WHICH MEANS STEPS', () {
    // The near miss this role exists to prevent. `movement` is the product's
    // other amber and it is an IDENTITY: borrowing it would say "steps" inside
    // the card about biological age.
    expect(kHaloWarm, isNot(LightFamilies.movement));
    expect(kHaloWarm, isNot(DarkFamilies.movement));
    expect(kHaloWarm, isNot(LightFamilies.movementSoft));
    expect(kHaloWarm, isNot(DarkFamilies.movementSoft));
  });

  test('the glint is on the canvas, not just in the ink set', () async {
    // The ink can be right while the branch that reads `mark.glint` is not, and
    // that is exactly the shape of the bug this replaced: one line choosing a
    // colour for one particle in eleven.
    expect(
      await _warmPixels(const HealtheeColors.dark()),
      greaterThan(0),
      reason: 'no warm pixel: the glint ink is resolved but never painted',
    );
  });

  test('a halo painted with no glint has no warm pixel at all', () async {
    // The control for the test above: the same field, the same ground, the
    // glint ink replaced by the body ink. If this ever finds warm pixels the
    // detector is measuring something other than the glint.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & _box);
    const colors = HealtheeColors.dark();
    canvas.drawRect(Offset.zero & _box, Paint()..color = colors.bioBackground);
    final ink = HaloInk.of(colors);
    final clock = ValueNotifier<double>(4);
    HaloPainter(
      clock: clock,
      ink: HaloInk(
        core: ink.core,
        mist: ink.mist,
        glint: ink.core,
        additive: ink.additive,
      ),
      alignment: Alignment.center,
    ).paint(canvas, _box);
    clock.dispose();
    final image = await recorder.endRecording().toImage(300, 230);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    var warm = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i] - bytes[i + 2] > 20) {
        warm++;
      }
    }
    expect(warm, 0);
  });
}
