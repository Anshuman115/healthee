/// **The halo has two kinds of particle, and they are drawn as two kinds.**
///
/// `design/mobile-preview/bio-halo.js` sizes them an order of magnitude apart.
/// The rim is 1,120 grains of `size: .3 + noise * 1.1` — fine dust. The 280
/// stream heads are `3 + noise(i+60) * 5`, drawn as a radial-gradient sprite
/// that is opaque only to 12% of its radius, with a hard `arc` core under one in
/// three. A soft head an order wider than a grain, and a solid core no bigger
/// than one.
///
/// This painter had a single `radius` per mark and gave every one of the 1,400 a
/// wide `drawPoints` glow — and a round-capped stroke is a **solid disc**, not a
/// gradient. So the rim's dust wore the stream heads' extent as hard colour, and
/// the owner, comparing the build with the prototype, said the balls were too
/// big. They were.
///
/// Everything below is asked of the painted geometry — the recorded stroke
/// widths, matched back to the marks that produced them — at four real phone
/// widths, never at the 800 px test default that hides every width mistake.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/v02/instruments/halo_field.dart';
import 'package:healthee/shared/v02/instruments/halo_painter.dart';

import '../../features/_hero_probe.dart';
import '../../features/_today_host.dart';
import '_instrument_probe.dart';

/// Floating-point slack, in logical pixels. A quantised extent is compared
/// against the bound it was derived from, so this only absorbs the arithmetic.
const double _slack = 1e-9;

/// One batched pass of round dots: how wide each one is, and where they are.
typedef _Dots = ({double width, List<Offset> at});

/// Every `drawPoints` pass that draws DOTS. The trails are the same call in
/// `PointMode.lines` and are not particles, so they are not counted here.
List<_Dots> _dotsOf(List<RecordedInvocation> calls) => <_Dots>[
  for (final call in calls)
    if (call.invocation.memberName == #drawPoints &&
        call.invocation.positionalArguments[0] == ui.PointMode.points)
      (
        width: (call.invocation.positionalArguments[2] as Paint).strokeWidth,
        at: call.invocation.positionalArguments[1] as List<Offset>,
      ),
];

/// One painted frame of the real hero at a phone width, with each kind of
/// particle's coordinates resolved from the field the painter itself used.
typedef _Frame = ({
  HaloField field,
  List<_Dots> dots,
  List<Offset> dust,
  Set<Offset> cored,
  Set<Offset> flowing,
});

Future<_Frame> _frameAt(
  WidgetTester tester,
  LocalStore store,
  double width,
) async {
  await pumpHeroAt(tester, store, width);
  final dots = _dotsOf(paintedAt(tester, heroField));
  final painter = tester.widget<CustomPaint>(heroField).painter! as HaloPainter;
  final field = painter.field!;
  // The clock that replay painted at, so the marks resolved here are the marks
  // those stroke widths were produced from.
  final time = painter.clock.value;
  final dust = <Offset>[];
  for (var i = 0; i < field.ring.length; i++) {
    final mark = field.ringMark(i, time);
    if (mark != null) {
      dust.add(mark.at);
    }
  }
  final cored = <Offset>{};
  final flowing = <Offset>{};
  for (var i = 0; i < field.streams.length; i++) {
    final mark = field.streamMark(i, time);
    if (mark == null) {
      continue;
    }
    flowing.add(mark.at);
    if (mark.core > 0) {
      cored.add(mark.at);
    }
  }
  return (field: field, dots: dots, dust: dust, cored: cored, flowing: flowing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  test("THE FIELD SEEDS THE PROTOTYPE'S OWN TWO SIZES", () {
    // The port, before any painting: the two populations are an order of
    // magnitude apart in `bio-halo.js`, and they are here too.
    final field = HaloField(
      size: kHaloReferenceBox,
      centre: kHaloReferenceBox.center(Offset.zero),
    );
    for (var i = 0; i < field.ring.length; i++) {
      final mark = field.ringMark(i, 4);
      if (mark == null) {
        continue;
      }
      expect(mark.glow, 0, reason: 'a grain of rim dust carries a glow');
      expect(
        mark.core / field.unit,
        inInclusiveRange(kHaloDustMin, kHaloDustMax),
      );
    }
    var cores = 0;
    for (var i = 0; i < field.streams.length; i++) {
      final mark = field.streamMark(i, 4);
      if (mark == null) {
        continue;
      }
      expect(
        mark.glow / field.unit,
        inInclusiveRange(kHaloGlowMin, kHaloGlowMax),
      );
      if (mark.core > 0) {
        cores++;
        expect(mark.core / field.unit, lessThan(kHaloCoreMax));
      }
    }
    expect(cores, greaterThan(0), reason: 'no stream carries a hard core');
  });

  testWidgets('THE RIM IS DUST — 0.3 to 1.4 units, and NOT ONE GLOW', (
    tester,
  ) async {
    // The regression itself. A grain drawn at the stream heads' extent is a
    // solid ball six times too wide, 1,120 times over.
    for (final width in kPhoneWidths) {
      final frame = await _frameAt(tester, store, width);
      final unit = frame.field.unit;
      final grains = frame.dust.toSet();
      expect(grains, isNotEmpty, reason: '$width: no rim was painted at all');
      var painted = 0;
      for (final batch in frame.dots) {
        final grainsHere = batch.at.where(grains.contains).length;
        if (grainsHere == 0) {
          continue;
        }
        painted += grainsHere;
        expect(
          batch.width,
          lessThanOrEqualTo(kHaloDustMax * unit + _slack),
          reason: '$width: rim dust drawn at ${batch.width / unit} units',
        );
        expect(
          batch.width,
          greaterThanOrEqualTo(kHaloDustMin * unit - _slack),
          reason: '$width: rim dust drawn too fine to see',
        );
      }
      expect(
        painted,
        frame.dust.length,
        reason: '$width: the rim is painted more than once — a glow is back',
      );
    }
  });

  testWidgets('A STREAM KEEPS ITS SOFT HEAD AND ITS HARD CORE', (tester) async {
    for (final width in kPhoneWidths) {
      final frame = await _frameAt(tester, store, width);
      final unit = frame.field.unit;
      final heads = <_Dots>[
        for (final batch in frame.dots)
          if (batch.at.any(frame.flowing.contains)) batch,
      ];
      expect(heads, isNotEmpty, reason: '$width: no stream was painted');
      final widest = heads
          .map((batch) => batch.width)
          .reduce((a, b) => a > b ? a : b);
      expect(
        widest / unit,
        inInclusiveRange(kHaloGlowMin, kHaloGlowMax),
        reason: "$width: the head is not the prototype's soft sprite",
      );
      // More than one pass over the same points is the falloff: the widest is
      // the dim edge, the narrower ones the bright middle.
      expect(
        heads.where((batch) => batch.width < widest),
        isNotEmpty,
        reason: '$width: one flat disc is not a falloff',
      );
      final cores = <_Dots>[
        for (final batch in frame.dots)
          if (batch.width < kHaloCoreMax * unit &&
              batch.at.isNotEmpty &&
              batch.at.every(frame.cored.contains))
            batch,
      ];
      expect(
        cores,
        isNotEmpty,
        reason: '$width: no hard core under any stream head',
      );
      for (final batch in cores) {
        expect(
          batch.width,
          greaterThanOrEqualTo(kHaloCoreMin * unit - _slack),
          reason: "$width: the core is finer than the prototype's",
        );
      }
    }
  });

  testWidgets("NOTHING IS DRAWN WIDER THAN THE PROTOTYPE'S WIDEST", (
    tester,
  ) async {
    for (final width in kPhoneWidths) {
      final frame = await _frameAt(tester, store, width);
      // The box is the card's, so a claim in units is a claim about this phone
      // and not about the 800 px surface `flutter test` defaults to.
      expect(frame.field.size.width, lessThan(width));
      expect(frame.dots, isNotEmpty);
      for (final batch in frame.dots) {
        expect(
          batch.width,
          lessThanOrEqualTo(kHaloGlowMax * frame.field.unit + _slack),
          reason:
              '$width: a mark ${batch.width / frame.field.unit} units across',
        );
      }
    }
  });
}
