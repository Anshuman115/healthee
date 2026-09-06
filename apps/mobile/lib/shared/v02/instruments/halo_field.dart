/// The halo's particle model: where every mark is at a given moment, and
/// nothing else. No colour, no canvas, no widget.
///
/// **Ported from `design/mobile-preview/bio-halo.js`.** The noise function, the
/// ripple, the inward easing `pow(1 - progress, 1.3)` and the four-edge spawn
/// are that file's, coefficient for coefficient — a "tidier" curve is a
/// different field, and the prototype is the thing the owner approved.
///
/// ## This decoration encodes no measurement, by construction
///
/// Every particle here is seeded from its own index through [haloNoise]. There
/// is no constructor parameter carrying a reading, no count derived from a
/// value, no radius scaled by a score. The halo cannot say anything about the
/// owner because it is never told anything about them — which is the only way to
/// keep a decoration honest next to a number. `README.md` is explicit that the
/// figure itself never animates; the halo moves, the measurement does not.
///
/// ## The cost cap lives here as a budget, not as a promise
///
/// The prototype caps two things: frames (30 fps) and pixel density
/// (`min(devicePixelRatio, 2)`). Flutter's canvas is resolution-independent —
/// there is no device-pixel knob on a `CustomPaint` — so the equivalent
/// discipline is a **particle budget scaled to the painted area** and capped at
/// the prototype's 1,400. A halo drawn twice as large costs the same as this
/// one; a halo drawn in a thumbnail costs a quarter. `bio_halo.dart` owns the
/// other half, the 30 fps clock.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

/// Deterministic value noise. `bio-halo.js`: `sin(v * 127.1 + 311.7) * 43758.5453`.
double haloNoise(num value) {
  final n = math.sin(value * 127.1 + 311.7) * 43758.5453;
  return n - n.floorToDouble();
}

/// A full turn.
const double kTau = math.pi * 2;

/// Particles orbiting the rim at full budget. With [kHaloStreamCount], the
/// prototype's 1,400.
const int kHaloRingCount = 1120;

/// Particles flowing inward from the four edges at full budget.
const int kHaloStreamCount = 280;

/// The box the budget is quoted for — `BioHero.artRect`, 300 x 230.
const Size kHaloReferenceBox = Size(300, 230);

/// The rim's radius as a share of the box's short side. Prototype: 112 / 320.
const double kHaloRingRatio = 0.35;

/// **The still centre.** Nothing is painted inside this share of the rim's
/// radius, so the figure the halo surrounds keeps its contrast.
const double kHaloStillRatio = 0.72;

/// The floor on the area budget: a small halo still reads as a halo.
const double kHaloMinimumBudget = 0.25;

/// The rim's dust, in reference pixels. `bio-halo.js`: `size: .3 + noise * 1.1`,
/// which is the whole of a grain — the solid part of its sprite is smaller still.
const double kHaloDustMin = 0.3;

/// The widest grain of rim dust. See [kHaloDustMin].
const double kHaloDustMax = 1.4;

/// A stream head's soft extent. `bio-halo.js`: `size = 3 + noise(i+60) * 5`,
/// drawn as a radial-gradient sprite that is opaque only to 12% of its radius.
const double kHaloGlowMin = 3;

/// The widest stream head. See [kHaloGlowMin].
const double kHaloGlowMax = 8;

/// The hard core one stream in three carries under that glow. `bio-halo.js`:
/// `arc(x, y, .35 + noise(i+40) * .4)` — a **diameter** of `.7 + noise * .8`.
const double kHaloCoreMin = 0.7;

/// The largest that core gets. See [kHaloCoreMin].
const double kHaloCoreMax = 1.5;

/// One painted mark, and **which kind of particle it is**, said in what it is
/// drawn with: the rim's dust is a hard [core] and no [glow]; a stream is a soft
/// [glow] with, one in three, a hard core under it. Either may be zero; no mark
/// has neither.
///
/// Both are DIAMETERS in logical pixels, because a round-capped `drawPoints`
/// stroke width is a diameter. They replace a single `radius` the painter could
/// not tell the kinds apart by — which is how 1,120 grains of rim dust ended up
/// wearing the 280 stream heads' glow, and why the field read as a bag of balls.
typedef HaloMark = ({
  Offset at,
  double alpha,
  double core,
  double glow,
  bool glint,
});

/// A particle orbiting the rim.
@immutable
class HaloRingParticle {
  /// Seeds one particle from its index, exactly as `bio-halo.js` does.
  HaloRingParticle(int index)
    : angle = haloNoise(index + 1) * kTau,
      spread = (haloNoise(index + 80) - 0.5) * (index % 3 == 0 ? 60 : 22),
      size = 0.3 + haloNoise(index + 210) * 1.1,
      phase = haloNoise(index + 450) * kTau,
      speed = 0.32 + haloNoise(index + 120) * 0.38,
      glint = index % 11 == 0;

  /// Where on the rim it starts.
  final double angle;

  /// How far off the rim it sits, in reference pixels. Signed.
  final double spread;

  /// Its dot size, in reference pixels.
  final double size;

  /// Its own offset into the breathing cycle.
  final double phase;

  /// How fast it breathes.
  final double speed;

  /// One in eleven is a glint — brighter, and drawn in the glint ink.
  final bool glint;
}

/// A particle flowing inward from one of the four edges.
@immutable
class HaloStreamParticle {
  /// Builds one stream. Geometry depends on the box, so this is not seeded from
  /// the index alone — see [HaloField._stream].
  const HaloStreamParticle({
    required this.angle,
    required this.start,
    required this.end,
    required this.duration,
    required this.phase,
    required this.curve,
    required this.glow,
    required this.core,
    required this.glint,
    required this.trail,
  });

  /// The bearing from the centre to its spawn point.
  final double angle;

  /// Its distance from the centre when it spawns, at the card's edge.
  final double start;

  /// Where it stops: the rim. Streams never enter the still centre.
  final double end;

  /// Seconds for one journey.
  final double duration;

  /// Its offset into that journey, 0-1.
  final double phase;

  /// How much it curves on the way in.
  final double curve;

  /// The extent of its soft head, in reference pixels. [kHaloGlowMin] to
  /// [kHaloGlowMax].
  final double glow;

  /// The diameter of the hard core under that head, in reference pixels. Only
  /// painted when [trail]: the prototype draws both on the same one in three.
  final double core;

  /// Drawn in the glint ink.
  final bool glint;

  /// Whether it drags a short tail. One in three, so direction is visible
  /// without every particle smearing.
  final bool trail;
}

/// The whole field at one size: the particles, and where they are at time `t`.
class HaloField {
  /// Builds the field for a box of [size] centred on [centre].
  HaloField({required this.size, required this.centre})
    : ringRadius = kHaloRingRatio * math.min(size.width, size.height),
      unit = math.min(size.width, size.height) / 320 {
    stillRadius = ringRadius * kHaloStillRatio;
    final area = size.width * size.height;
    final reference = kHaloReferenceBox.width * kHaloReferenceBox.height;
    budget = (area / reference).clamp(kHaloMinimumBudget, 1.0);
    ring = <HaloRingParticle>[
      for (var i = 0; i < (kHaloRingCount * budget).round(); i++)
        HaloRingParticle(i),
    ];
    streams = <HaloStreamParticle>[
      for (var i = 0; i < (kHaloStreamCount * budget).round(); i++) _stream(i),
    ];
  }

  /// The box this field was built for.
  final Size size;

  /// What the field orbits — the point the figure sits on.
  final Offset centre;

  /// The rim's radius in logical pixels.
  final double ringRadius;

  /// One reference pixel, so the prototype's 320-wide numbers scale.
  final double unit;

  /// Nothing is painted inside this radius.
  late final double stillRadius;

  /// The share of the full 1,400 this size earns, 0.25-1.
  late final double budget;

  /// The rim's orbiting particles.
  late final List<HaloRingParticle> ring;

  /// The particles flowing in from the edges.
  late final List<HaloStreamParticle> streams;

  /// How many particles this field draws at all. The cost, in one number.
  int get particleCount => ring.length + streams.length;

  HaloStreamParticle _stream(int index) {
    final side = index % 4;
    final across = haloNoise(index + 870);
    final margin = 8 * unit;
    final x = switch (side) {
      0 => margin,
      1 => size.width - margin,
      _ => margin + across * (size.width - margin * 2),
    };
    final y = switch (side) {
      2 => margin,
      3 => size.height - margin,
      _ => margin + across * (size.height - margin * 2),
    };
    final away = Offset(x, y) - centre;
    return HaloStreamParticle(
      angle: away.direction,
      start: math.max(away.distance, ringRadius),
      end: ringRadius * (0.98 + haloNoise(index + 80) * 0.04),
      duration: 6 + haloNoise(index + 680) * 5,
      phase: haloNoise(index + 930),
      curve: (haloNoise(index + 450) - 0.5) * 0.28,
      glow:
          kHaloGlowMin + haloNoise(index + 60) * (kHaloGlowMax - kHaloGlowMin),
      core:
          kHaloCoreMin + haloNoise(index + 40) * (kHaloCoreMax - kHaloCoreMin),
      glint: index % 13 == 0,
      trail: index % 3 == 0,
    );
  }

  /// The rim's wobble, `bio-halo.js`'s `point()`.
  Offset pointAt(double angle, double radius, double time) {
    final ripple =
        math.sin(angle * 7 + time * 0.95) * 2.8 * unit +
        math.cos(angle * 13 - time * 0.7) * 1.8 * unit;
    return centre +
        Offset(math.cos(angle), math.sin(angle)) * (radius + ripple);
  }

  /// Rim particle [index] at [time], or null when it would fall in the still
  /// centre — which is the still centre's only enforcement.
  HaloMark? ringMark(int index, double time) {
    final particle = ring[index];
    final drift = index.isEven ? 0.07 : -0.045;
    final angle =
        particle.angle +
        time * drift +
        math.sin(time * particle.speed + particle.phase) * 0.065;
    final radius =
        ringRadius +
        particle.spread * unit +
        math.sin(time * 0.85 + particle.phase) * 4 * unit;
    // The ripple is applied INSIDE pointAt, so the guard has to be on the
    // painted position: a particle whose orbit clears the still centre can
    // still be rippled into it, and it was.
    final at = pointAt(angle, radius, time);
    if ((at - centre).distance < stillRadius) {
      return null;
    }
    final life =
        0.45 + (0.5 + 0.5 * math.sin(time * 1.5 + particle.phase)) * 0.55;
    final depth = math.max(0.18, 1 - particle.spread.abs() / 26);
    // No glow, and no `i % 5` either: the prototype's fivefold size step is on
    // the SPRITE, and the rim's sprite is what this field does not draw. What is
    // left is the grain itself, at the size `bio-halo.js` seeded it.
    return (
      at: at,
      alpha: (life * depth * 0.8).clamp(0.0, 1.0),
      core: particle.size * unit,
      glow: 0,
      glint: particle.glint,
    );
  }

  /// How far along its journey stream [index] is at [time], 0-1.
  double streamProgress(int index, double time) {
    final stream = streams[index];
    return (stream.phase + time / stream.duration) % 1;
  }

  /// Where stream [index] is at [progress] through its journey.
  Offset streamPoint(int index, double progress) {
    final stream = streams[index];
    final radius =
        stream.end + (stream.start - stream.end) * math.pow(1 - progress, 1.3);
    final angle = stream.angle + stream.curve * math.sin(progress * math.pi);
    return centre + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  /// Stream [index] at [time]. Brightens as it nears the rim, which is the
  /// "flowing inward and merging" the README describes.
  HaloMark? streamMark(int index, double time) {
    final stream = streams[index];
    final progress = streamProgress(index, time);
    final at = streamPoint(index, progress);
    if ((at - centre).distance < stillRadius) {
      return null;
    }
    final fade = math.min(
      1.0,
      math.min(progress / 0.12, (1 - progress) / 0.12),
    );
    return (
      at: at,
      alpha: (fade * (0.3 + progress * 0.65)).clamp(0.0, 1.0),
      core: stream.trail ? stream.core * unit : 0,
      glow: stream.glow * unit,
      glint: stream.glint,
    );
  }

  /// The tail end of stream [index]'s trail, or null when it drags none.
  Offset? trailFrom(int index, double time) {
    if (!streams[index].trail) {
      return null;
    }
    final progress = streamProgress(index, time);
    return streamPoint(index, math.max(0, progress - 0.022));
  }

  /// One filament — a slow closed strand just outside the rim, which is what
  /// gives the ring depth without a blur filter.
  Path filament(int strand, double time) {
    const samples = 72;
    final path = Path();
    for (var i = 0; i <= samples; i++) {
      final angle = i / samples * kTau;
      final radius =
          ringRadius *
          (0.97 +
              math.sin(angle * 5 + strand * 0.9 + time * 0.65) * 0.027 +
              strand * 0.006);
      final point = pointAt(angle, radius, time);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }
}
