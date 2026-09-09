/// The metric explorer — what it lists, and what it refuses to print.
///
/// The claim this file exists for is the **coverage** one. A directory screen
/// that quietly lists nineteen of twenty metrics looks completely correct: the
/// tiles are right, the layout is right, and the one door that is missing is
/// missing in a place nobody is looking. So the list is asserted against
/// `HistoryMetric.values` itself rather than against a copy of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/history/history_metric.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/features/history/metric_explorer_screen.dart';
import 'package:healthee/features/history/v02/metric_tile.dart';
import 'package:healthee/shared/v02/metric_tone.dart';

import '../_today_stubs.dart';
import '../shared/_v02_harness.dart';
import '_history_host.dart';

/// The contract snapshot with `weight_kg` withheld.
///
/// The committed payload carries `withheld: null` for every card, so the state
/// this app exists to render honestly is not in it. The block is the server's
/// own shape (`envelope.dart`), and the sentence is the one prod sends when a
/// weigh-in has aged out of the VO₂max freshness horizon.
TodayView _withWithheldWeight() => todayView(
  mutate: (json) {
    for (final card in json['metrics']! as List<Object?>) {
      final row = card! as Map<String, Object?>;
      if (row['metric'] == 'weight_kg') {
        row['value'] = null;
        row['withheld'] = <String, Object?>{
          'reason': 'logged_weight_stale',
          'message': kStaleWeight,
          'last_as_of_date': '2026-06-04',
        };
      }
    }
    return json;
  },
);

/// The refusal the withheld tile must print, whole.
const String kStaleWeight =
    'Your last weigh-in is 61 days old. Log a current weight and this comes '
    'back.';

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  TodayView? view,
}) async {
  tester.view
    ..physicalSize = Size(width, 4000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    historyHost(
      const MetricExplorerScreen(),
      view: view ?? todayView(),
      width: width,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  useRealFonts();

  group('coverage', () {
    test('THE EXPLORER LISTS EVERY METRIC THE APP HAS A HISTORY FOR', () {
      final entries = explorerEntries(todayView().snapshot);
      expect(
        entries.map((entry) => entry.metric).toList(),
        HistoryMetric.values.map((metric) => metric.id).toList(),
      );
      expect(entries.length, HistoryMetric.values.length);
    });

    test('every tile carries a name and never an id', () {
      for (final entry in explorerEntries(todayView().snapshot)) {
        expect(entry.title, isNotEmpty);
        expect(
          entry.title,
          isNot(equals(entry.metric)),
          reason: '${entry.metric} has no owner-facing name',
        );
        expect(entry.title, isNot(contains('_')));
      }
    });

    test('the list survives a server that never answered', () {
      // The doors are the app's, not the payload's: a screen that lists nothing
      // when `/api/today` is unreachable would hide twenty working histories.
      final entries = explorerEntries(null);
      expect(entries.length, HistoryMetric.values.length);
      expect(entries.every((entry) => entry.value == null), isTrue);
    });
  });

  group('the readings', () {
    test('come from the server’s own cards, then its sparklines', () {
      final entries = <String, MetricEntry>{
        for (final entry in explorerEntries(todayView().snapshot))
          entry.metric: entry,
      };
      // `metrics[]` — the card's own label and figure.
      expect(entries['steps_total']!.value, isNotNull);
      // `sparklines` — no card, but the same day's series.
      expect(entries['sleep_regularity_index']!.value, isNotNull);
      // Neither: the em dash, and the caption says what it means.
      expect(entries['sleep_need_min']!.value, isNull);
    });

    testWidgets('A WITHHELD READING RENDERS AS WITHHELD, WITH ITS REASON', (
      tester,
    ) async {
      // `weight_kg` is withheld in the contract snapshot. The refusal is the
      // server's sentence, printed whole — a tile that trimmed it to fit would
      // be a refusal that stopped saying what to do about it.
      final weight = explorerEntries(
        _withWithheldWeight().snapshot,
      ).firstWhere((entry) => entry.metric == 'weight_kg');
      expect(weight.reading, isA<Withheld<double>>());
      expect(weight.value, isNull);

      await _pump(tester, view: _withWithheldWeight());
      expect(find.text(kStaleWeight), findsOneWidget);
      // The tile that refused draws no figure beside the sentence.
      final tile = tester.widget<MetricTile>(
        find.byWidgetPredicate(
          (widget) => widget is MetricTile && widget.entry.metric == 'weight_kg',
        ),
      );
      expect(tile.entry.value, isNull);
    });
  });

  group('geometry', () {
    testWidgets('a tile wears its family on a 2 px top rule, and nowhere else', (
      tester,
    ) async {
      await _pump(tester);
      final tiles = find.byType(MetricTile);
      expect(tiles, findsNWidgets(HistoryMetric.values.length));

      final tile = find.byWidgetPredicate(
        (widget) => widget is MetricTile && widget.entry.metric == 'rhr_daily',
      );
      // The rule is a clipped band rather than a border edge — `metric_tile.dart`
      // records why Flutter cannot draw the CSS literally. It is asserted as
      // GEOMETRY: two logical pixels tall, the full width of the tile, at its top.
      final rule = find.descendant(of: tile, matching: find.byType(ColoredBox));
      expect(tester.widget<ColoredBox>(rule).color, kHues.heart);
      expect(toneForMetric('rhr_daily').family(kHues), kHues.heart);
      final band = tester.getRect(rule);
      final face = tester.getRect(tile);
      expect(band.height, MetricTile.topRule);
      expect(band.width, closeTo(face.width, 0.5));
      expect(band.top, closeTo(face.top, 0.5));

      // The other three edges are the ordinary rule, not the family.
      final container = tester.widget<Container>(
        find.descendant(of: tile, matching: find.byType(Container)).first,
      );
      // One `BorderSide` for all four edges, so "the family is only the top
      // rule" is a claim about a rule drawn OVER a uniform edge, not about an
      // edge that is family-coloured on one side.
      expect(edgeOf(container.decoration!)!.color, kColors.line);
    });

    testWidgets('the two columns are equal at every phone width', (
      tester,
    ) async {
      for (final width in kPhoneWidths) {
        await _pump(tester, width: width);
        final tiles = tester.widgetList<MetricTile>(find.byType(MetricTile));
        final first = tester.getSize(find.byWidget(tiles.first));
        final second = tester.getSize(find.byWidget(tiles.elementAt(1)));
        expect(first.width, closeTo(second.width, 0.5), reason: 'at $width');
        expect(first.width, greaterThan(0));
        expect(tester.takeException(), isNull, reason: 'at $width');
      }
    });
  });

  group('what a screen must never print', () {
    testWidgets('no raw id and no citation marker anywhere on it', (
      tester,
    ) async {
      await _pump(tester);
      for (final text in textsOn(tester)) {
        expect(text, isNot(contains('_')));
        expect(text, isNot(contains('[')));
      }
    });

    testWidgets('the dash is explained rather than left to be read as zero', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text(kDashCaption), findsOneWidget);
      expect(find.text(kExplorerCaption), findsOneWidget);
    });
  });
}
