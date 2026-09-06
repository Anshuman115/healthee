/// How the halo's marks are quantised into batches cheap enough to draw.
///
/// Split out of `halo_painter.dart` at the 400-line gate (Standards section 1).
/// It is the whole of the cost discipline that is not the particle budget: a
/// batch is one `drawPoints`, and 1,400 particles cost a few dozen of them.
library;

import 'dart:ui';

import 'package:healthee/shared/v02/instruments/halo_field.dart';

/// One bucket ready to draw: its points, its drawn extent in logical pixels,
/// its brightness 0-1, and whether it is the glint ink.
typedef HaloBatch = ({
  List<Offset> at,
  double extent,
  double alpha,
  bool glint,
});

/// What [HaloBatches.forEach] hands each bucket to.
typedef HaloBatchDraw = void Function(HaloBatch batch);

/// Marks quantised into buckets that can each be drawn in one call.
///
/// A bucket is one ink, one extent and one brightness, so everything in it is a
/// point in a single `drawPoints` — a few dozen calls for 1,400 particles rather
/// than 1,400. Extents quantise to bucket **centres**, never to the ends of the
/// range: the widest dot drawn is then inside the prototype's range instead of
/// sitting exactly on its edge, where a rounding error reads as a regression.
class HaloBatches {
  /// Buckets extents between [min] and [max] reference pixels into [steps], and
  /// brightness into [bands]. [unit] is one reference pixel.
  HaloBatches({
    required this.unit,
    required this.min,
    required this.max,
    required this.steps,
    required this.bands,
  });

  /// One reference pixel in logical pixels.
  final double unit;

  /// The narrowest extent this batcher expects, in reference pixels.
  final double min;

  /// The widest.
  final double max;

  /// How many extents it quantises to.
  final int steps;

  /// How many brightnesses.
  final int bands;

  final Map<int, List<Offset>> _points = <int, List<Offset>>{};

  /// Files [mark] under the bucket [extent] logical pixels belongs to. An
  /// extent of zero is the mark saying it has no dot of this kind at all.
  void add(HaloMark mark, double extent) {
    if (extent <= 0 || mark.alpha <= 0) {
      return;
    }
    final step = ((extent / unit - min) / (max - min) * steps).floor().clamp(
      0,
      steps - 1,
    );
    final band = (mark.alpha * bands).ceil().clamp(1, bands);
    (_points[(((mark.glint ? 1 : 0) * steps) + step) * bands + band] ??=
            <Offset>[])
        .add(mark.at);
  }

  /// Hands every bucket to [draw].
  void forEach(HaloBatchDraw draw) {
    for (final entry in _points.entries) {
      final key = entry.key - 1;
      final centre = (key ~/ bands % steps + 0.5) / steps;
      draw((
        at: entry.value,
        extent: (min + centre * (max - min)) * unit,
        alpha: (key % bands + 1) / bands,
        glint: key ~/ bands ~/ steps == 1,
      ));
    }
  }
}
