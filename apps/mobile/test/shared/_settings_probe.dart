/// The one decoration reader the two primitive suites share.
///
/// Not a `*_test.dart` file, so it is never run as a suite. Extracted when the
/// primitives outgrew one 400-line file — two copies of a decoration reader is
/// two chances for the two halves to measure different things.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `BoxDecoration` of the [Container] that [finder] resolves to.
BoxDecoration boxOf(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;
