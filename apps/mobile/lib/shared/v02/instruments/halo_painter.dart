/// What the halo's particles are painted with, and how they are painted cheaply.
///
/// ## Three inks, all of them palette roles
///
/// `motion.css` gives the prototype `--halo-core`, `--halo-mist` and
/// `--halo-warm`, and the glint is **warm** — `oklch(88% .13 86)`, the amber
/// `HealtheeColors.haloWarm` carries verbatim.
///
/// It shipped once as a brightness event instead (`bioGlow` lifted toward
/// `bioInk`), to avoid importing the `movement` family's amber into the
/// biological-age card. The reasoning was sound and the call was wrong: the
/// answer to "the only amber we have means steps" is a halo role of its own,
/// which `palette.dart` now holds in both themes, not a different design. The
/// glint does not borrow `movement` and never did.
///
/// ## The ground decides the blend, because additive light on a pale ground is
/// white mush
///
/// The prototype composites `lighter` on a surface that its own `motion.css`
/// forces dark in both themes. Our `bioBackground` follows the page: pale in
/// light, dark in dark. Additive blending is therefore chosen from the ground's
/// luminance — glow that adds on a dark surface, ink that lays over a pale one.
/// A single blend mode would have shipped a halo that is invisible in one theme,
/// which is the failure `chart_ink_test.dart` exists to catch elsewhere.
///
/// ## No blur filter, anywhere
///
/// A `MaskFilter.blur` per particle is a saved layer per particle, and a
/// gradient shader per particle is a shader per particle. So the prototype's
/// soft sprite is approximated by [kHaloGlowPasses] concentric `drawPoints`
/// passes — the blend sums them into a stepped cone — and the rim's halo is one
/// gradient-filled annulus. Roughly 60 draw calls a frame for up to 1,400
/// particles, at the 30 fps `bio_halo.dart` clocks.
///
/// ## The two kinds of particle are drawn as two kinds
///
/// `bio-halo.js` sizes them an order of magnitude apart, and the glow belongs to
/// exactly one of them. The rim's 1,120 grains are hard dots of
/// [kHaloDustMin]–[kHaloDustMax] reference pixels and nothing else; the 280
/// stream heads get the soft falloff, with a hard core under one in three. A
/// painter that cannot tell them apart gives the dust the heads' glow, which is
/// the bug this file shipped: fourteen hundred balls where there should have
/// been dust around a ring.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/v02/instruments/halo_batches.dart';
import 'package:healthee/shared/v02/instruments/halo_field.dart';

/// How many brightness bands particles are quantised into before batching.
const int kHaloAlphaBands = 3;

/// How many size buckets the rim's dust is quantised into.
const int kHaloSizeBuckets = 3;

/// How many the stream heads get. Fewer, because each bucket costs
/// [kHaloGlowPasses] calls rather than one, and a soft edge hides the step.
const int kHaloGlowBuckets = 2;

/// And how many brightness bands they get, for the same reason.
const int kHaloGlowBands = 2;

/// Concentric passes standing in for the prototype's radial-gradient sprite.
const int kHaloGlowPasses = 3;

/// How many filament strands ring the rim.
const int kHaloFilaments = 5;

/// The halo's three inks and how they meet the ground.
@immutable
class HaloInk {
  /// Builds an ink set directly. Prefer [HaloInk.of].
  const HaloInk({
    required this.core,
    required this.mist,
    required this.glint,
    required this.additive,
  });

  /// Resolves the inks from the bio roles, choosing the blend from the ground.
  factory HaloInk.of(HealtheeColors colors) {
    final dark = colors.bioBackground.computeLuminance() < 0.5;
    return HaloInk(
      core: dark ? colors.bioGlow : colors.bioLine,
      mist: colors.bioLine,
      // The prototype's own amber, whichever way the ground goes. `--halo-warm`
      // is declared once in `motion.css` for a halo surface that is dark in
      // both themes, so there is nothing here to pick between.
      glint: colors.haloWarm,
      additive: dark,
    );
  }

  /// The particle body — `--halo-core`.
  final Color core;

  /// The rim's depth and the filaments — `--halo-mist`.
  final Color mist;

  /// One particle in eleven — `--halo-warm`, the prototype's amber.
  final Color glint;

  /// Whether marks add light (dark ground) or lay ink over it (pale ground).
  final bool additive;

  /// The blend every mark uses.
  BlendMode get blend => additive ? BlendMode.plus : BlendMode.srcOver;

  /// How loud a mark is allowed to be on this ground.
  double get weight => additive ? 1 : 0.55;

  @override
  bool operator ==(Object other) =>
      other is HaloInk &&
      other.core == core &&
      other.mist == mist &&
      other.glint == glint &&
      other.additive == additive;

  @override
  int get hashCode => Object.hash(core, mist, glint, additive);
}

/// Paints [HaloField] at whatever second its [clock] currently reads.
///
/// The clock is the `repaint` listenable, so a paused halo issues no repaints at
/// all — see `bio_halo.dart`. `shouldRepaint` is false on purpose: this painter
/// is driven by the clock, never by rebuilds.
class HaloPainter extends CustomPainter {
  /// Builds the painter. [alignment] places the still centre.
  HaloPainter({
    required this.clock,
    required this.ink,
    required this.alignment,
  }) : super(repaint: clock);

  /// Seconds of halo time. Frozen while the halo is paused.
  final ValueListenable<double> clock;

  /// The three inks.
  final HaloInk ink;

  /// Where the still centre sits in the box.
  final Alignment alignment;

  HaloField? _field;

  /// The field last built, for tests that assert the still centre is respected.
  HaloField? get field => _field;

  HaloField _fieldFor(Size size) {
    final centre = alignment.withinRect(Offset.zero & size);
    final cached = _field;
    if (cached != null && cached.size == size && cached.centre == centre) {
      return cached;
    }
    return _field = HaloField(size: size, centre: centre);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final field = _fieldFor(size);
    final time = clock.value;
    _paintRim(canvas, field);
    _paintFilaments(canvas, field, time);
    _paintTrails(canvas, field, time);
    _paintDust(canvas, field, time);
    _paintStreams(canvas, field, time);
  }

  /// The rim's glow: **an annulus**, so the still centre is a hole in the
  /// geometry rather than a transparent stop nobody can verify.
  void _paintRim(Canvas canvas, HaloField field) {
    final outer = field.ringRadius * 1.5;
    final inner = field.stillRadius;
    final bounds = Rect.fromCircle(center: field.centre, radius: outer);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(bounds)
      ..addOval(Rect.fromCircle(center: field.centre, radius: inner));
    final clear = ink.mist.withValues(alpha: 0);
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = ink.blend
        ..shader = RadialGradient(
          colors: <Color>[
            clear,
            ink.mist.withValues(alpha: 0.16 * ink.weight),
            ink.core.withValues(alpha: 0.1 * ink.weight),
            clear,
          ],
          stops: <double>[inner / outer, 0.7, 0.82, 1],
        ).createShader(bounds),
    );
  }

  void _paintFilaments(Canvas canvas, HaloField field, double time) {
    for (var strand = 0; strand < kHaloFilaments; strand++) {
      final glint = strand == 3;
      canvas.drawPath(
        field.filament(strand, time),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.45 * field.unit
          ..blendMode = ink.blend
          ..color = (glint ? ink.glint : ink.mist).withValues(
            alpha: (glint ? 0.12 : 0.07) * ink.weight,
          ),
      );
    }
  }

  /// Short outward tails, one per three streams, so direction is visible.
  void _paintTrails(Canvas canvas, HaloField field, double time) {
    final segments = <Offset>[];
    var alpha = 0.0;
    for (var i = 0; i < field.streams.length; i++) {
      final tail = field.trailFrom(i, time);
      final mark = field.streamMark(i, time);
      if (tail == null || mark == null) {
        continue;
      }
      segments.add(tail);
      segments.add(mark.at);
      alpha += mark.alpha;
    }
    if (segments.isEmpty) {
      return;
    }
    canvas.drawPoints(
      ui.PointMode.lines,
      segments,
      Paint()
        ..strokeWidth = 0.6 * field.unit
        ..blendMode = ink.blend
        ..color = ink.core.withValues(
          alpha: (alpha / segments.length * 2 * 0.35 * ink.weight).clamp(
            0.0,
            1.0,
          ),
        ),
    );
  }

  /// The rim's dust: a hard dot each, at the size `bio-halo.js` seeded it, and
  /// **not one of them glowing**. The ring's light is the annulus and the
  /// filaments; a glow per grain is what made the field read as a bag of balls.
  void _paintDust(Canvas canvas, HaloField field, double time) {
    final dust = HaloBatches(
      unit: field.unit,
      min: kHaloDustMin,
      max: kHaloDustMax,
      steps: kHaloSizeBuckets,
      bands: kHaloAlphaBands,
    );
    for (var i = 0; i < field.ring.length; i++) {
      final mark = field.ringMark(i, time);
      if (mark != null) {
        dust.add(mark, mark.core);
      }
    }
    dust.forEach(
      (dot) => canvas.drawPoints(
        ui.PointMode.points,
        dot.at,
        _dot(
          glint: dot.glint,
          width: dot.extent,
          alpha: dot.alpha * ink.weight,
        ),
      ),
    );
  }

  /// The streams: a soft head, with a hard core under one in three.
  ///
  /// The prototype's head is a sprite — a radial gradient solid to 12% of its
  /// radius and transparent at the edge — and there is no cheap per-particle
  /// gradient here (see the library docstring). [kHaloGlowPasses] concentric
  /// dots, each carrying a share of the brightness, sum to a stepped cone
  /// instead: bright in the middle, faint at the rim, no layer saved. The core
  /// is the prototype's own `arc`, and it is solid because the prototype's is.
  void _paintStreams(Canvas canvas, HaloField field, double time) {
    final glow = HaloBatches(
      unit: field.unit,
      min: kHaloGlowMin,
      max: kHaloGlowMax,
      steps: kHaloGlowBuckets,
      bands: kHaloGlowBands,
    );
    final cores = HaloBatches(
      unit: field.unit,
      min: kHaloCoreMin,
      max: kHaloCoreMax,
      steps: kHaloGlowBuckets,
      bands: kHaloAlphaBands,
    );
    for (var i = 0; i < field.streams.length; i++) {
      final mark = field.streamMark(i, time);
      if (mark == null) {
        continue;
      }
      glow.add(mark, mark.glow);
      cores.add(mark, mark.core);
    }
    glow.forEach((dot) {
      for (var pass = kHaloGlowPasses; pass >= 1; pass--) {
        canvas.drawPoints(
          ui.PointMode.points,
          dot.at,
          _dot(
            glint: dot.glint,
            width: dot.extent * pass / kHaloGlowPasses,
            alpha: dot.alpha * ink.weight / kHaloGlowPasses,
          ),
        );
      }
    });
    cores.forEach(
      (dot) => canvas.drawPoints(
        ui.PointMode.points,
        dot.at,
        _dot(
          glint: dot.glint,
          width: dot.extent,
          alpha: dot.alpha * ink.weight,
        ),
      ),
    );
  }

  /// One batched pass of round dots, [width] across — a stroke width on a
  /// round-capped `drawPoints` is the dot's DIAMETER.
  Paint _dot({
    required bool glint,
    required double width,
    required double alpha,
  }) => Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width
    ..blendMode = ink.blend
    ..color = (glint ? ink.glint : ink.core).withValues(
      alpha: alpha.clamp(0.0, 1.0),
    );

  @override
  bool shouldRepaint(HaloPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.alignment != alignment;
}
