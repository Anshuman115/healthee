/// Probes the two vitals-honesty suites share: what a card SAYS and what it USES.
///
/// Extracted on their second use (Standards §1), when the single suite passed
/// the 400-line gate and split in two. The helpers are the interesting part —
/// [forbiddenOfArousal] in particular is a direct transcription of
/// `wearable_stress_validity` D1/D2 — and a second copy of that list is a second
/// chance for the two suites to disagree about what the corpus forbids.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/features/today/widgets/metric_note.dart';

import '../shared/_chart_probe.dart';

/// Words that name a feeling, a mood, or a band of one.
///
/// D1 and D2 forbid every one of them **about this number**. The device's own
/// word "stress" is deliberately NOT here: the card's foot says "the strap calls
/// this stress" on purpose, so the reader can connect the label they see to the
/// label on the watch. What is banned is the step from a signal to a state —
/// "stressed", "calm", "tense" — and every band that implies one.
const List<String> forbiddenOfArousal = <String>[
  'stressed',
  'stressful',
  'calm',
  'relaxed',
  'tense',
  'anxious',
  'anxiety',
  'worried',
  'excited',
  'overwhelmed',
  'mood',
  'emotion',
  'emotional',
  'mental',
  'feeling',
  'high stress',
  'low stress',
  'elevated',
  'normal range',
];

/// Every string the card puts on screen.
List<String> textOf(WidgetTester tester, Finder card) => <String>[
  for (final text in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  ))
    text.data ?? '',
];

/// The interpretive sentence under the chart, and only that.
///
/// Scoped deliberately. `wearable_spo2_validity` D3 forbids *calling out* an
/// individual low reading — making a claim about it — not printing the range of
/// the series drawn directly above it. Legacy's `LOWEST 14N 88%` caption is the
/// same kind of statement as the heart-rate card's `49–112 bpm` header: it
/// describes the axis, not the owner. Interpretation is the note's job, so the
/// note is what these tests read.
String noteOf(WidgetTester tester, Finder card) => tester
    .widget<MetricNote>(
      find.descendant(of: card, matching: find.byType(MetricNote)),
    )
    .text
    .toLowerCase();

/// Every colour the card uses — painted into the chart, or set on a label.
Set<int> paletteOf(WidgetTester tester, Finder card, Finder chart) => <int>{
  ...coloursOf(paintedBy(tester, chart)),
  for (final text in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  ))
    if (text.style?.color case final Color colour) colour.toARGB32(),
};

/// The three tokens `palette.dart` rations to judgement, and their fills.
Set<int> verdictsOf(HealtheeColors colors) => <int>{
  colors.fav.toARGB32(),
  colors.favSoft.toARGB32(),
  colors.unf.toARGB32(),
  colors.unfSoft.toARGB32(),
  colors.alert.toARGB32(),
  colors.alertSoft.toARGB32(),
};
