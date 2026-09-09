/// Reading a painted ground, whichever decoration drew it.
///
/// The app uses BOTH `BoxDecoration` and `ShapeDecoration`, and which one a
/// surface uses is an implementation detail of its corner: anything drawn with
/// `hSquircle` — the continuous superellipse the whole design is built on — needs
/// a `ShapeBorder`, and only `ShapeDecoration` takes one. A circle, a bare fill
/// or a plain rule stays a `BoxDecoration`.
///
/// Tests were casting straight to `BoxDecoration`, so converting a card's corner
/// threw `type 'ShapeDecoration' is not a subtype of type 'BoxDecoration'` in
/// nineteen tests that were only ever asking what colour the thing was. That is a
/// test coupled to a shape decision it does not care about.
library;

import 'package:flutter/material.dart';

/// The fill a container paints, whichever decoration it used.
Color? groundOf(Decoration? decoration) => switch (decoration) {
  BoxDecoration(:final Color? color) => color,
  ShapeDecoration(:final Color? color) => color,
  _ => null,
};
