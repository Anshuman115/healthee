/// `H.historyPanel` as this app draws it — the figure, the absence, the count.
///
/// Three claims live in this card and all three can be wrong quietly:
///
///   * the figure is **the chosen day's**, never the newest one in the window;
///   * a day with no row says so in words rather than showing a bare dash;
///   * the count under the chart counts **readings**, not chart slots.
///
/// The prototype gets the third one wrong — its blood-oxygen panel says
/// *"14 dated samples through 24 Jul"* over a chart that drew nothing, because
/// it counts the array it sliced. That is the one departure from pixel-for-pixel
/// here and it is in the honesty layer, so it is pinned rather than left to be
/// re-introduced by the next person who reads the prototype.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/history/history_window.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/shared/charts/v02/chart_curve.dart';
import 'package:healthee/shared/charts/v02/v02_line_chart.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/dated_panel.dart';

const List<TrendPoint> _holed = <TrendPoint>[
  TrendPoint(date: '2026-03-07', value: 40),
  TrendPoint(date: '2026-03-08', value: 42),
  // 09 and 10 are missing.
  TrendPoint(date: '2026-03-11', value: 39),
];

Widget _host(
  String metric,
  String unit,
  String day, {
  List<TrendPoint> points = _holed,
  int days = 5,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: DatedPanel(
      metric: metric,
      unit: unit,
      day: day,
      window: HistoryWindow.endingOn(points, day, days),
      reveals: RevealRegistry(),
    ),
  ),
);

void main() {
  testWidgets('THE FIGURE IS THE CHOSEN DAY’S, NOT THE WINDOW’S NEWEST', (
    tester,
  ) async {
    // 11 March holds 39 and is the newest reading in the series. Asked for the
    // 8th, the card must say 42 — a card that reached for the latest value
    // would be stale-as-current at one panel's scale.
    await tester.pumpWidget(_host('rhr_daily', 'bpm', '2026-03-08'));
    expect(find.text('42'), findsOneWidget);
    expect(find.text('39'), findsNothing);
    expect(find.text('8 Mar'), findsOneWidget);
  });

  testWidgets('A DAY WITH NO READING SAYS SO, AND OFFERS NO REMEDY', (
    tester,
  ) async {
    await tester.pumpWidget(_host('rhr_daily', 'bpm', '2026-03-09'));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('No reading on this day'), findsOneWidget);
    // Nothing here tells the owner to do something about a day that is over.
    expect(find.textContaining('Sync'), findsNothing);
    expect(find.textContaining('Try'), findsNothing);
  });

  testWidgets('THE COUNT IS OF READINGS, NOT OF CHART SLOTS', (tester) async {
    // Five calendar days in the window and three readings inside it.
    await tester.pumpWidget(_host('rhr_daily', 'bpm', '2026-03-11'));
    expect(find.text('3 dated samples through 11 Mar.'), findsOneWidget);
    expect(find.textContaining('5 dated'), findsNothing);
  });

  testWidgets('a window with no readings at all counts none', (tester) async {
    await tester.pumpWidget(_host('rhr_daily', 'bpm', '2026-03-01'));
    expect(find.text('No dated samples through 1 Mar.'), findsOneWidget);
  });

  testWidgets('one reading is a sample, not samples', (tester) async {
    await tester.pumpWidget(
      _host('rhr_daily', 'bpm', '2026-03-11', days: 1),
    );
    expect(find.text('1 dated sample through 11 Mar.'), findsOneWidget);
  });

  testWidgets('A TOTAL IS JOINED STRAIGHT; A SIGNAL MAY BE SPLINED', (
    tester,
  ) async {
    // `chart_curve.dart`'s rule, at the one call site this feature adds: a
    // spline between Tuesday's and Wednesday's step totals draws counts nobody
    // reached, and can draw one lower than either day.
    await tester.pumpWidget(_host('steps_total', 'steps', '2026-03-11'));
    expect(
      tester.widget<V02LineChart>(find.byType(V02LineChart)).curve,
      SeriesCurve.straight,
    );

    await tester.pumpWidget(_host('hrv_sleep_avg', 'ms', '2026-03-11'));
    expect(
      tester.widget<V02LineChart>(find.byType(V02LineChart)).curve,
      SeriesCurve.monotone,
    );
  });

  testWidgets('THE CHART IS HANDED THE HOLES, NOT A SQUEEZED SERIES', (
    tester,
  ) async {
    await tester.pumpWidget(_host('rhr_daily', 'bpm', '2026-03-11'));
    expect(
      tester.widget<V02LineChart>(find.byType(V02LineChart)).values,
      <double?>[40, 42, null, null, 39],
    );
  });

  group('the reading behind the figure', () {
    test('a measured day is Present', () {
      final window = HistoryWindow.endingOn(_holed, '2026-03-11', 5);
      expect(readingOn(window, '2026-03-08'), const Present<double>(42));
    });

    test('AN UNMEASURED DAY IS WITHHELD, WITH A REASON AND NO REMEDY', () {
      final window = HistoryWindow.endingOn(_holed, '2026-03-11', 5);
      final reading = readingOn(window, '2026-03-09');
      expect(reading, isA<Withheld<double>>());
      final disclosure = (reading as Withheld<double>).disclosure;
      expect(disclosure.reason, kNoReadingReason);
      expect(disclosure.message, 'No reading on this day');
    });
  });

  test('the note is built from what was observed', () {
    final window = HistoryWindow.endingOn(_holed, '2026-03-11', 5);
    expect(datedPanelNote(window, '2026-03-11'), contains('3 dated samples'));
    expect(
      datedPanelNote(HistoryWindow.endingOn(_holed, '2026-03-01', 5), '2026-03-01'),
      'No dated samples through 1 Mar.',
    );
  });
}
