/// The non-widget half of the ported foundation: the corner, the motion scale
/// and the type roles.
///
/// Split from `instrument_primitives_test.dart` at the 400-line gate. These are
/// pure values, and pure values are exactly where a transcription goes wrong
/// without anything looking broken — a smoothness of 0.5, a curve of
/// `Curves.easeOut`, an eyebrow tracked in ems where legacy tracked it in
/// pixels. None of those would fail to compile and none would fail a render.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/motion.dart';
import 'package:healthee/core/theme/shapes.dart';
import 'package:healthee/core/theme/tokens.dart';

const HealtheeColors _light = HealtheeColors.light();

void main() {
  group('hSquircle', () {
    test('is legacy’s continuous corner, at legacy’s smoothness', () {
      expect(kSquircleSmoothness, 0.6);
      final shape = hSquircle(Radii.card);
      expect(shape, isA<ShapeBorder>());
    });

    test('THE CARD SHAPE IS THE SQUIRCLE, not a rounded rectangle', () {
      // One definition of the corner in the app. A `RoundedRectangleBorder`
      // reappearing here would change every card on every screen.
      expect(
        hSquircle(Radii.card).runtimeType,
        isNot(RoundedRectangleBorder),
      );
    });
  });

  group('HMotion', () {
    test('carries legacy’s four durations and its signature ease', () {
      expect(HMotion.fast, const Duration(milliseconds: 200));
      expect(HMotion.base, const Duration(milliseconds: 450));
      expect(HMotion.slow, const Duration(milliseconds: 950));
      expect(HMotion.stagger, const Duration(milliseconds: 40));
      expect(HMotion.curve, const Cubic(0.2, 0.7, 0.3, 1));
    });
  });

  group('HType', () {
    test('every role is Inter, and every role is tabular', () {
      for (final style in <TextStyle>[
        HType.serif(_light.ink),
        HType.sans(_light.ink),
        HType.number(_light.ink),
        HType.label(_light.ink3),
        HType.eyebrow(_light.ink3),
      ]) {
        expect(style.fontFamily, 'Inter');
        expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    });

    test('the metrics are legacy’s, to the coefficient', () {
      expect(HType.serif(_light.ink).fontSize, 23);
      expect(HType.serif(_light.ink).height, 1.05);
      expect(HType.serif(_light.ink).letterSpacing, closeTo(-0.23, 1e-9));
      expect(HType.sans(_light.ink).fontSize, 14);
      expect(HType.sans(_light.ink).fontWeight, FontWeight.w500);
      expect(HType.number(_light.ink).fontSize, 27);
      expect(HType.number(_light.ink).letterSpacing, closeTo(-0.216, 1e-9));
      expect(HType.label(_light.ink3).fontSize, 9);
      // 0.12 em of tracking at 9 px.
      expect(HType.label(_light.ink3).letterSpacing, closeTo(1.08, 1e-9));
      // The eyebrow's 1.6 is a flat pixel value in legacy, not an em multiple.
      expect(HType.eyebrow(_light.ink3).letterSpacing, 1.6);
    });
  });
}
