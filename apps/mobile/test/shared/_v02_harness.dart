/// The harness the v02 primitive suites share.
///
/// Not a `*_test.dart` file, so it is never run as a suite. It exists because
/// the primitives outgrew one 400-line file and two copies of a pump helper is
/// two chances for the two halves to measure different things.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';

/// `richer.css`: `#main { padding: 20px 16px 112px }` on a 360 dp phone.
const double kContentWidth = 328;

/// The theme every measurement below is taken in. Dark is v02's default.
const HealtheeColors kColors = HealtheeColors.dark();

/// Its families.
const InstrumentHues kHues = InstrumentHues.dark();

/// Pumps [child] at the phone's content width.
///
/// [width] of null leaves the child unconstrained, which is what an
/// intrinsically sized primitive needs: a tight 328 would stretch `IconTile`'s
/// 40 and the test would measure the harness rather than the widget.
Future<void> pumpV02(
  WidgetTester tester,
  Widget child, {
  Tone? tone,
  double? width = kContentWidth,
}) async {
  final Widget content = width == null
      ? child
      : SizedBox(width: width, child: child);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: tone == null ? content : ToneScope(tone: tone, child: content),
        ),
      ),
    ),
  );
}

/// The `BoxDecoration` of the [Container] that [finder] resolves to.
BoxDecoration decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

/// The radius of a `BorderRadius.circular` decoration.
double radiusOf(BoxDecoration decoration) =>
    (decoration.borderRadius! as BorderRadius).topLeft.x;
