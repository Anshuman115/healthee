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
///   * **A cell never carries the reason, and the screen it opens always does.**
///     The second half moved when the sections moved: the owning card is now on
///     the tab the cell taps through to, so the tests assert the DOOR here and
///     the card on its new screen in `tab_screens_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/models/recovery_score.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/activity/widgets/biological_age_card.dart';
import 'package:healthee/features/activity/widgets/cardio_load_card.dart';
import 'package:healthee/features/activity/widgets/mvpa_card.dart';
import 'package:healthee/features/activity/widgets/steps_card.dart';
import 'package:healthee/features/activity/widgets/vo2max_card.dart';
import 'package:healthee/features/activity/widgets/workouts_card.dart';
import 'package:healthee/features/diagnostics/widgets/metric_strip.dart';
import 'package:healthee/features/diagnostics/widgets/server_metric_strip.dart';
import 'package:healthee/features/insights/widgets/findings_section.dart';
import 'package:healthee/features/sleep/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/sleep/widgets/recovery_ladder.dart';
import 'package:healthee/features/sleep/widgets/sleep_debt_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_dimensions_card.dart';
import 'package:healthee/features/sleep/widgets/sleep_week_card.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/widgets/daily_action_card.dart';
import 'package:healthee/features/today/widgets/grid_module.dart';
import 'package:healthee/features/today/widgets/heart_rate_card.dart';
import 'package:healthee/features/today/widgets/illness_banner.dart';
import 'package:healthee/features/today/widgets/metric_grid.dart';
import 'package:healthee/features/today/widgets/stress_card.dart';
import 'package:healthee/shared/charts/h_spark.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/states/value_hole.dart';

import '../_today_stubs.dart';
import '_screen_data.dart';
import '_today_host.dart';

const Disclosure _refused = Disclosure(
  reason: 'insufficient_nights',
  message: 'Wear the strap overnight for a few more nights.',
);

/// One cell, on its own, in the light theme. [onOpen] records the door.
Widget cellHost(
  Reading<double> reading, {
  List<double> spark = const [55, 57, 54],
  VoidCallback? onOpen,
}) {
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
          onOpen: onOpen ?? () {},
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

    testWidgets('EVERY MODULE IS A DOOR, AND EACH LEADS TO ITS OWN TAB', (
      tester,
    ) async {
      // Legacy's grid cells all carry `onClick={() => onOpen(...)}` and that is
      // what makes Today an index. A cell may show a bare hole only because the
      // screen behind it carries the reason and the remedy in full.
      final opened = <String>[];
      await tester.pumpWidget(
        todayHost(store, home: _GridProbe(onOpen: opened.add)),
      );
      await tester.pumpAndSettle();

      for (final entry in <String, String>{
        'SLEEP': Routes.sleep,
        'RESTING HR': Routes.sleep,
        'HRV': Routes.sleep,
        'RESP / SPO\u2082': Routes.sleep,
        'STEPS': Routes.activity,
        'ENERGY': Routes.activity,
      }.entries) {
        opened.clear();
        await tester.tap(inGrid(entry.key), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(
          opened,
          [entry.value],
          reason: '${entry.key} must open the tab its full card moved to',
        );
      }
    });
  });

  group('the shape of the screen', () {
    /// The real section list, built the way the screen builds it.
    List<PageSection> sections() =>
        todaySections(screenData(server: todayView()), const TodayExtras());

    int indexOf<T>(List<PageSection> list) =>
        list.indexWhere((section) => section.child is T);

    test('THE ILLNESS FLAG COMES BEFORE EVERY NUMBER IT OVERRIDES', () {
      final list = sections();
      final flag = indexOf<IllnessBanner>(list);
      expect(flag, isNonNegative, reason: 'the fixture carries an active flag');
      // Brief \u00a74.1 \u2014 it outranks everything, so nothing on this screen can be
      // read before the sentence that overrides it.
      for (final after in <int>[
        indexOf<MetricGrid>(list),
        indexOf<HeartRateCard>(list),
      ]) {
        expect(after, greaterThan(flag));
      }
    });

    test("TODAY IS LEGACY'S SHAPE AND NOTHING ELSE", () {
      // `screen_today.jsx` is 140 lines: readiness, the six-module grid, the
      // 24-hour heart rate, stress, and one suggested action. The revision this
      // replaces ran to twenty cards. A card reappearing here is a card that has
      // stopped being behind a door.
      final list = sections();
      // The readiness instrument arrives wrapped in its honesty view, which is
      // the point of `ReadingView` — a withheld recovery renders the refusal in
      // the same slot rather than dropping the section.
      for (final present in <int>[
        indexOf<ReadingView<RecoveryScore>>(list),
        indexOf<MetricGrid>(list),
        indexOf<HeartRateCard>(list),
        indexOf<StressCard>(list),
        indexOf<DailyActionCard>(list),
      ]) {
        expect(present, isNonNegative);
      }
      expect(
        list,
        hasLength(lessThanOrEqualTo(12)),
        reason:
            'Today is an index. Twenty sections is the screen this replaced, '
            'and the count is the only thing that catches a card creeping back.',
      );
    });

    test('NOTHING MOVED IS STILL ON TODAY', () {
      // Named by type so a card that comes home has to be deleted from this list
      // deliberately rather than by an import going quiet.
      final drawn = sections().map((section) => section.child.runtimeType).toSet();
      for (final moved in <Type>[
        SleepDimensionsCard,
        SleepDebtCard,
        SleepWeekCard,
        BloodOxygenCard,
        RecoveryLadder,
        StepsCard,
        CardioLoadCard,
        MvpaCard,
        WorkoutsCard,
        BiologicalAgeCard,
        Vo2maxCard,
        FindingsSection,
        ServerMetricStrip,
        MetricStrip,
      ]) {
        expect(
          drawn,
          isNot(contains(moved)),
          reason: '$moved moved to its own tab; Today indexes it, not shows it',
        );
      }
    });
  });
}

/// The grid alone, over the real providers, with its doors recorded.
///
/// Not the whole screen: `TodayScreen` wires `onOpen` to `context.go`, and a
/// widget test has no router \u2014 so the tap would fail for a reason that is about
/// the test rather than about the grid. The door itself is a parameter precisely
/// so it can be watched here.
class _GridProbe extends ConsumerWidget {
  const _GridProbe({required this.onOpen});

  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(deviceDayProvider).value;
    final snapshot = ref.watch(todaySnapshotProvider).value?.snapshot;
    if (day == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: MetricGrid(
          day: day,
          reveals: RevealRegistry(),
          snapshot: snapshot,
          onOpen: onOpen,
        ),
      ),
    );
  }
}
