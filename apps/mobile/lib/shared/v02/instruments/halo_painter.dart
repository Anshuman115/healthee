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
/// A `MaskFilter.blur` per particle is a saved layer per particle. The glow is
/// two `drawPoints` passes instead — one wide and dim, one small and bright —
/// and the rim's halo is one gradient-filled annulus. Roughly 40 draw calls a
/// frame for up to 1,400 particles, at the 30 fps `bio_halo.dart` clocks.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/v02/instruments/halo_field.dart';

/// How many brightness bands particles are quantised into before batching.
const int kHaloAlphaBands = 3;

/// How many size buckets they are quantised into.
const int kHaloSizeBuckets = 3;

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
    _paintParticles(canvas, field, time);
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

  /// Every particle, batched into (ink x size x brightness) buckets so 1,400
  /// dots cost a few dozen calls rather than 1,400.
  void _paintParticles(Canvas canvas, HaloField field, double time) {
    final buckets = <int, List<Offset>>{};
    void add(HaloMark? mark) {
      if (mark == null || mark.alpha <= 0) {
        return;
      }
      final band = (mark.alpha * kHaloAlphaBands).ceil().clamp(
        1,
        kHaloAlphaBands,
      );
      final size = ((mark.radius / field.unit - 0.3) / 0.75)
          .clamp(0, kHaloSizeBuckets - 1)
          .round();
      final key = (mark.glint ? 1 : 0) * 100 + size * 10 + band;
      (buckets[key] ??= <Offset>[]).add(mark.at);
    }

    for (var i = 0; i < field.ring.length; i++) {
      add(field.ringMark(i, time));
    }
    for (var i = 0; i < field.streams.length; i++) {
      add(field.streamMark(i, time));
    }
    for (final entry in buckets.entries) {
      final glint = entry.key >= 100;
      final size = entry.key % 100 ~/ 10;
      final band = entry.key % 10;
      final radius = (0.3 + size * 0.75) * field.unit;
      final alpha = band / kHaloAlphaBands * ink.weight;
      final colour = glint ? ink.glint : ink.core;
      // A glow without a blur: one wide dim pass under one small bright pass.
      canvas.drawPoints(
        ui.PointMode.points,
        entry.value,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 6
          ..blendMode = ink.blend
          ..color = colour.withValues(alpha: alpha * 0.18),
      );
      canvas.drawPoints(
        ui.PointMode.points,
        entry.value,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 2
          ..blendMode = ink.blend
          ..color = colour.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(HaloPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.alignment != alignment;
}
