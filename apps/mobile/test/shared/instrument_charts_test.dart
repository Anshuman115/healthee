/// `revealed()` — the one thing a reveal may do to a colour, and the one it may not.
///
/// ## What this file used to be
///
/// It was the suite for the three charts ported for the legacy Today — the tick
/// gauge, the meter and the spark. All three (`h_tick_gauge.dart`,
/// `h_meter.dart`, `h_spark.dart`) became unreachable from `main.dart` in the
/// v02 redesign and are deleted, and their assertions went with them.
///
/// `revealed()` did not: it lives in `chart_primitives.dart`, which every live
/// chart still reveals through, and the defect below is the reason it was
/// extracted in the first place.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

void main() {
  group('a reveal scales a colour, it does not overrule it', () {
    test('AN ALREADY-TRANSLUCENT TOKEN STAYS TRANSLUCENT AT FULL PROGRESS', () {
      // The bug `revealed` was extracted for: `withValues(alpha: progress)`
      // REPLACES the alpha, which turned the hypnogram's `awake` band — the 10%
      // hairline, chosen so the absence of sleep is the quietest thing on the
      // chart — into the loudest thing on it.
      const hairline = Color.fromRGBO(255, 255, 255, 0.10);
      expect(revealed(hairline, 1).a, closeTo(0.10, 0.005));
      expect(revealed(hairline, 0.5).a, closeTo(0.05, 0.005));
    });

    test('an opaque colour still fades in from nothing', () {
      expect(revealed(const Color(0xFF8F87FF), 0).a, 0);
      expect(revealed(const Color(0xFF8F87FF), 1).a, 1);
    });
  });
}
