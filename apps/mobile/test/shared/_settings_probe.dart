/// The one decoration reader the two primitive suites share.
///
/// Not a `*_test.dart` file, so it is never run as a suite. Extracted when the
/// primitives outgrew one 400-line file — two copies of a decoration reader is
/// two chances for the two halves to measure different things.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The decoration of the [Container] that [finder] resolves to.
///
/// Returns `Decoration`, not `BoxDecoration`: a surface drawn with `hSquircle`
/// needs a `ShapeBorder`, and only `ShapeDecoration` carries one. Read it with
/// the `groundOf` / `radiusOf` / `edgeOf` helpers rather than casting, so a test
/// about a colour is not coupled to a corner.
Decoration boxOf(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration!;
