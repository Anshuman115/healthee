/// What a card actually PUT ON SCREEN, as strings.
///
/// The one helper that outlived `_vitals_probe.dart`. That file carried the
/// roster of legacy's four vitals cards and the transcription of
/// `wearable_stress_validity` D1/D2 the four vitals suites shared; the v02
/// redesign removed the cards, the suites went with them, and what is left is
/// this — a reader that answers "what words are on this thing" without caring
/// what the thing is.
///
/// Kept as a shared helper rather than inlined because it is the honest way to
/// ask that question: `find.text` asserts a string somebody already thought of,
/// while this returns everything the widget drew, so a test can assert about
/// prose it did not predict.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every string the widget under [card] puts on screen, in tree order.
List<String> textOf(WidgetTester tester, Finder card) => <String>[
  for (final text in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  ))
    text.data ?? '',
];
