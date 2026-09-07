/// The host both history suites pump, and the fonts they measure in.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
///
/// The two screens read four providers between them, and every one of them
/// reaches a socket or the wall clock if it is left alone:
///
///   * `metricHistoryProvider` and `historyMarkersProvider` — `/api/history`.
///   * `todaySnapshotProvider` — `/api/today`, which fills the explorer's tiles.
///   * `todayProvider` and `viewDateProvider` — the wall clock, which would
///     make "is the reader on a past day" depend on the calendar.
///
/// ## Manrope, loaded
///
/// `flutter test`'s default font draws every glyph as a one-em box, so a
/// measured width is the character count rather than the text. Every geometric
/// assertion in these suites is therefore taken with the real faces loaded —
/// `test/core/typography_test.dart` established the pattern.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/typography.dart';
import 'package:healthee/data/history/history_marker.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/history/history_repository.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/store/view_date.dart';
import 'package:healthee/data/today_repository.dart';

import '../_today_stubs.dart';

/// The day every history suite calls "today".
const String kToday = '2026-08-04';

/// The period the screen opens on.
const int kDefaultDays = 90;

/// The widths a v02 layout is measured at. Never Flutter's 800 px default.
const List<double> kPhoneWidths = <double>[320, 360, 390, 414];

/// Loads Manrope, so a measured width is the text rather than the glyph count.
void useRealFonts() {
  setUpAll(() async {
    final loader = FontLoader(healtheeFontFamily);
    for (final face in Directory('assets/fonts')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.ttf'))) {
      loader.addFont(
        Future<ByteData>.value(face.readAsBytesSync().buffer.asByteData()),
      );
    }
    await loader.load();
  });
}

/// One history screen, with every provider it reads pinned.
///
/// [series] is what `/api/history` answers with for [metric] at [days]; a null
/// [view] leaves `/api/today` unreachable, which is what the metric screen sees
/// and what the explorer must survive.
Widget historyHost(
  Widget home, {
  HistoryMetric metric = HistoryMetric.hrv,
  int days = kDefaultDays,
  List<TrendPoint> series = const <TrendPoint>[],
  List<HistoryMarker> markers = const <HistoryMarker>[],
  TodayView? view,
  double width = 390,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      todayProvider.overrideWithValue(kToday),
      metricHistoryProvider(metric, days).overrideWith((ref) async => series),
      // Every period the segment offers, so tapping one does not fall through
      // to the real provider and its socket.
      for (final other in <int>[30, 90, 365, 1825])
        if (other != days)
          metricHistoryProvider(
            metric,
            other,
          ).overrideWith((ref) async => const <TrendPoint>[]),
      for (final other in <int>[30, 90, 365, 1825])
        historyMarkersProvider(
          other,
        ).overrideWith((ref) async => other == days ? markers : const []),
      todaySnapshotProvider.overrideWith(
        view == null ? todayUnreachable() : todayIs(view),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: home),
      ),
    ),
  );
}

/// Moves the reader onto [day], through the real notifier.
///
/// The provider is left REAL rather than overridden: what a past day does to
/// these screens is the notifier's own bounds plus the screens' reaction, and
/// an override would stub out the half that decides whether the day is even
/// reachable. `todayProvider` is pinned instead, so the window is a fixture.
Future<void> selectDay(WidgetTester tester, String day) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(viewDateProvider.notifier).select(day);
  await tester.pumpAndSettle();
}

/// Every string a screen actually rendered, in tree order.
List<String> textsOn(WidgetTester tester) => <String>[
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

/// The index of the first rendered string containing [needle], or -1.
int indexOfText(List<String> texts, String needle) =>
    texts.indexWhere((text) => text.contains(needle));
