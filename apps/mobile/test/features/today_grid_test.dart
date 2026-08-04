/// The Today grid: what a cell draws, and what it refuses to draw.
///
/// The grid is the dense head the rebuild exists for, and it is also the one
/// place on this screen that shows a value without room for its refusal's reason.
/// `grid_module.dart` explains why that is allowed; these tests hold the two
/// halves of the bargain it strikes.
///
///   * **A CELL WITH NO VALUE DRAWS A HOLE, NEVER A SPARKLINE.** A trend drawn
///     where today's reading is missing invites the eye to read its last point as
///     today — which is the number the cell just declined to show.
///   * **A cell never carries the reason, and the section below always does.**
///     The second half is asserted against the real screen, because it is a fact
///     about `today_sections.dart` and not about any one widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/widgets/grid_module.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/features/today/widgets/metric_grid.dart';
import 'package:healthee/features/today/widgets/metric_strip.dart';
import 'package:healthee/features/today/widgets/server_metric_strip.dart';
import 'package:healthee/features/today/widgets/steps_card.dart';
import 'package:healthee/shared/charts/h_spark.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/value_hole.dart';

import '../_today_stubs.dart';
import '_today_host.dart';

const Disclosure _refused = Disclosure(
  reason: 'insufficient_nights',
  message: 'Wear the strap overnight for a few more nights.',
);

/// One cell, on its own, in the light theme.
Widget cellHost(Reading<double> reading, {List<double> spark = const [55, 57, 54]}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => GridModule(
          label: 'Resting HR',
          tag: context.colors.accent,
          reading: reading,
          format: (value) => value.round().toString(),
          unit: 'bpm',
          spark: spark,
          foot: '30d median 55',
          reveals: RevealRegistry(),
          revealId: 'test.cell',
        ),
      ),
    ),
  );
}

void main() {
  group('a cell with a value', () {
    testWidgets('shows the figure, its unit and its personal comparison', (
      tester,
    ) async {
      await tester.pumpWidget(cellHost(const Present<double>(54)));
      await tester.pumpAndSettle();

      expect(find.text('RESTING HR'), findsOneWidget);
      expect(find.text('54'), findsOneWidget);
      expect(find.text('bpm'), findsOneWidget);
      // The owner's own 30-day median, never a population figure.
      expect(find.text('30D MEDIAN 55'), findsOneWidget);
      expect(find.byType(HSpark), findsOneWidget);
      expect(find.byType(ValueHole), findsNothing);
    });

    testWidgets('a caveated value is still a value, and is shown', (tester) async {
      await tester.pumpWidget(cellHost(const Caveated<double>(54, [_refused])));
      await tester.pumpAndSettle();

      expect(find.text('54'), findsOneWidget);
      expect(find.byType(ValueHole), findsNothing);
    });
  });

  group('a cell with no value', () {
    testWidgets('A WITHHELD CELL DRAWS A HOLE AND NO SPARKLINE', (tester) async {
      await tester.pumpWidget(cellHost(const Withheld<double>(_refused)));
      await tester.pumpAndSettle();

      expect(find.byType(ValueHole), findsOneWidget);
      expect(
        find.byType(HSpark),
        findsNothing,
        reason:
            'a trend under a missing value invites the last point to be read '
            'as today',
      );
      expect(find.text('54'), findsNothing);
    });

    testWidgets('the cell keeps its label and its footprint, and points onward', (
      tester,
    ) async {
      await tester.pumpWidget(cellHost(const Withheld<double>(_refused)));
      await tester.pumpAndSettle();

      // Same title, same position — it reads as the app being careful, not as a
      // cell that failed to load.
      expect(find.text('RESTING HR'), findsOneWidget);
      expect(find.text(GridModule.withheldFoot.toUpperCase()), findsOneWidget);
      // And NOT the reason: there is no room for the remedy beside it, and half
      // a remedy is worse than none.
      expect(find.textContaining('Wear the strap overnight'), findsNothing);
    });
  });

  group('the grid on the real screen', () {
    late LocalStore store;

    /// [text] inside the grid, which is where a label is unique — several of
    /// these words are also factor rows in the readiness instrument above, and
    /// that is the grid and the instrument agreeing rather than a duplicate.
    Finder inGrid(String text) =>
        find.descendant(of: find.byType(ModuleGrid), matching: find.text(text));

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets("carries all six of legacy's modules", (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, inGrid('RESP / SPO\u2082'));

      for (final label in <String>[
        'SLEEP',
        'RESTING HR',
        'HRV',
        'STEPS',
        'ENERGY',
        'RESP / SPO\u2082',
      ]) {
        expect(inGrid(label), findsOneWidget, reason: '$label is a grid module');
      }
    });

    testWidgets('the sleep cell reads the SERVER night the judgements came from', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, inGrid('SLEEP'));

      // `last_sleep.duration_min` is 380 in the contract snapshot; the strap row
      // the store was seeded with is a different night. Showing the server's is
      // what keeps its sleep-health judgement from sitting beside a night it was
      // not computed from.
      expect(inGrid('6:20'), findsOneWidget);
      expect(inGrid('DEEP 90M \u00b7 REM 90M'), findsOneWidget);
    });

    testWidgets('renders in BOTH themes, not just the one it was built in', (
      tester,
    ) async {
      // The screen this replaced was dark-only in practice. Both token sets are
      // authored (`palette.dart`), and a widget that reached past them for a
      // literal would be correct in one theme and wrong in the other — which is
      // a bug nobody sees until they toggle.
      for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(todayHost(store, themeOverride: theme));
        await tester.pumpAndSettle();
        await reveal(tester, inGrid('STEPS'));
        expect(tester.takeException(), isNull);
        expect(inGrid('STEPS'), findsOneWidget);
      }
    });

    testWidgets('A REFUSED CELL IS ALWAYS BACKED BY THE FULL CARD BELOW', (
      tester,
    ) async {
      // The grid's promise: a cell may show only a hole because the section that
      // owns the metric is on the same screen with the reason and the remedy.
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('From the strap'));

      expect(
        find.textContaining('The strap recorded no'),
        findsWidgets,
        reason: 'the strap streams refuse in their own words further down',
      );
    });
  });

  group('the order of the screen', () {
    /// The real section list, built the way the screen builds it.
    List<TodaySection> sections() => todaySections(
      day: DeviceDay.empty('2026-08-04'),
      reveals: RevealRegistry(),
      server: todayView(),
    );

    int indexOf<T>(List<TodaySection> list) =>
        list.indexWhere((section) => section.child is T);

    test('THE ILLNESS FLAG COMES BEFORE EVERY NUMBER IT OVERRIDES', () {
      final list = sections();
      final flag = indexOf<IllnessBanner>(list);
      expect(flag, isNonNegative, reason: 'the fixture carries an active flag');
      // Brief \u00a74.1 \u2014 it outranks everything, so nothing on this screen can be
      // read before the sentence that overrides it. Including the guidance in
      // the greeting, which the flag rewrites.
      for (final after in <int>[
        indexOf<MetricGrid>(list),
        indexOf<HeartRateCard>(list),
      ]) {
        expect(after, greaterThan(flag));
      }
    });

    test('EVERY GRID SLOT HAS ITS FULL CARD FURTHER DOWN', () {
      // The bargain `grid_module.dart` strikes: a cell may show a hole with no
      // reason because the section owning that metric is always on this list.
      // Delete one of these and a refusal quietly becomes a shrug.
      final list = sections();
      final grid = indexOf<MetricGrid>(list);
      expect(grid, isNonNegative);
      for (final owner in <int>[
        indexOf<StepsCard>(list), // Steps
        indexOf<MetricStrip>(list), // HRV, Resp / SpO\u2082, Resting HR
        indexOf<ServerMetricStrip>(list), // Resting HR, Energy
      ]) {
        expect(
          owner,
          greaterThan(grid),
          reason: 'a grid cell with no section under it is a refusal with no '
              'reason anywhere on the screen',
        );
      }
    });
  });
}
