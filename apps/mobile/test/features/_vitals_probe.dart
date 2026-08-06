/// The probes the vitals suites share: the four cards, what they SAY, what they USE.
///
/// Extracted on their second use (Standards §1), when the single suite passed
/// the 400-line gate and split. The helpers are the interesting part —
/// [forbiddenOfStress] in particular is a direct transcription of
/// `wearable_stress_validity` D1/D2, and [vitalsCards] is the roster four suites
/// now agree on — and a second copy of either is a second chance for the suites
/// to disagree about what the corpus forbids or about what is on the screen.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/today_series.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/hrv_trend_card.dart';
import 'package:healthee/features/today/widgets/metric_note.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/shared/charts/h_area.dart';
import 'package:healthee/shared/charts/h_bars.dart';
import 'package:healthee/shared/charts/h_deviation.dart';
import 'package:healthee/shared/charts/h_night_line.dart';
import 'package:healthee/shared/reveal_once.dart';

import '../shared/_chart_probe.dart';

/// Words that name a feeling, a mood, or a band of one.
///
/// D1 and D2 forbid every one of them **about this number**. The device's own
/// word "stress" is deliberately NOT here, and after 2026-08-06 it is the card's
/// title again: the note forbids the step from a signal to a state —
/// "stressed", "calm", "tense" — and every band that implies one. Naming the
/// metric what the strap, the legacy app and every other surface name it is not
/// that step, and pretending otherwise cost the owner the word for his own data.
const List<String> forbiddenOfStress = <String>[
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

/// Twelve hours of an ordinary day, as the server aggregates them.
List<HourPoint> hours() => <HourPoint>[
  for (var i = 0; i < 12; i++)
    HourPoint(
      hour: 6 + i,
      average: 62 + (i % 5) * 7,
      minimum: 58,
      maximum: 96,
      count: 60,
    ),
];

/// One vitals card: its name, a FRESH instance, and the finder for its chart.
///
/// A builder rather than a widget because a `RevealRegistry` remembers that a
/// chart has animated — reusing one instance across two tests would paint the
/// second one at a progress the first left behind.
typedef VitalsCard = ({String name, Widget Function() build, Finder chart});

/// The four charts the owner's two reports are about, in screen order.
List<VitalsCard> vitalsCards() => <VitalsCard>[
  (
    name: 'HRV',
    build: () => HrvTrendCard(
      series: const <double>[41, 47, 39, 52, 44, 48, 43],
      reading: const Present<double>(43),
      baseline: 45,
      reveals: RevealRegistry(),
    ),
    chart: find.byType(HDeviation),
  ),
  (
    name: 'stress',
    build: () => StressCard(
      intraday: const <double>[30, 44, 38, 51, 33, 29, 47],
      daily: const <double>[],
      reveals: RevealRegistry(),
    ),
    chart: find.byType(HBars),
  ),
  (
    name: 'heart rate',
    build: () => HeartRateDayCard(
      points: hours(),
      restingHeartRate: const Present<double>(55),
      reveals: RevealRegistry(),
    ),
    chart: find.byType(HArea),
  ),
  (
    name: 'blood oxygen',
    build: () => BloodOxygenCard(
      minima: const <double>[95, 94, 96, 93, 95, 94, 96],
      reading: const Present<double>(97),
      reveals: RevealRegistry(),
    ),
    chart: find.byType(HNightLine),
  ),
];

/// Every string the card puts on screen.
List<String> textOf(WidgetTester tester, Finder card) => <String>[
  for (final text in tester.widgetList<Text>(
    find.descendant(of: card, matching: find.byType(Text)),
  ))
    text.data ?? '',
];

/// Every laid-out `Text` in [card], as the rect it really occupies.
List<Rect> textRectsOf(WidgetTester tester, Finder card) {
  final texts = find.descendant(of: card, matching: find.byType(Text));
  return <Rect>[
    for (var i = 0; i < tester.widgetList<Text>(texts).length; i++)
      tester.getRect(texts.at(i)),
  ];
}

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
