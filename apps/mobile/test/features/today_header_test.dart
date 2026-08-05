/// The editorial head of Today: legacy's greeting header, and the tab bar.
///
/// The header is `_GreetingHeader` ported (`today_screen.dart:433`) — an eyebrow
/// date, the strap's charge, the avatar, and a two-line display greeting. The
/// tests here hold the three things about it that are claims rather than layout:
/// the date table has no off-by-one, the greeting follows legacy's two
/// boundaries, and **no cheerful phrase sits beside a safety sentence**.
///
/// That last one is why the greeting is the greeting and nothing else. Legacy
/// tints a fragment of an opening sentence, and the obvious way to reproduce it
/// is to derive a phrase from `recovery_score.band`. The contract snapshot is
/// exactly the case that makes it a bug: `band: "high"` beside guidance that
/// begins "An illness signal is active".
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/tabs.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/widgets/greeting_header.dart';
import 'package:healthee/shared/app_tab_bar.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';

import '_today_host.dart';

/// One widget in the light theme.
Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

Widget _header({
  String date = '2026-08-06',
  DateTime? at,
  int? battery,
  bool syncing = false,
}) => host(
  GreetingHeader(
    date: date,
    now: at ?? DateTime(2026, 8, 6, 9),
    batteryPercent: battery,
    syncing: syncing,
  ),
);

void main() {
  group('the date eyebrow', () {
    testWidgets("abbreviates the day and month, as legacy's does", (tester) async {
      await tester.pumpWidget(_header());
      await tester.pumpAndSettle();

      expect(find.text('THU · AUG 6'), findsOneWidget);
    });

    test('every weekday and month has a name', () {
      // Off-by-one in a hand-rolled name table is the classic version of this
      // bug, and it only shows on one day of the week.
      expect(prettyDate('2026-01-05'), 'MON · JAN 5');
      expect(prettyDate('2026-12-27'), 'SUN · DEC 27');
    });

    test('an unparseable date keeps its own text rather than going blank', () {
      // Legacy's `catch` — a date we cannot read is still information, and a gap
      // where a date belongs reads as a broken header.
      expect(prettyDate('not-a-date'), 'NOT-A-DATE');
    });
  });

  group('the greeting', () {
    test("follows legacy's two boundaries", () {
      // Legacy has no small-hours case, so 03:00 really is "Good morning".
      expect(greetingFor(DateTime(2026, 8, 4, 3)), 'Good morning');
      expect(greetingFor(DateTime(2026, 8, 4, 9)), 'Good morning');
      expect(greetingFor(DateTime(2026, 8, 4, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 8, 4, 21)), 'Good evening');
    });

    testWidgets('addresses nobody by name, because nothing stores one', (
      tester,
    ) async {
      await tester.pumpWidget(_header());
      await tester.pumpAndSettle();

      // Legacy's own fallback (`today_screen.dart:443`), not an invention — and
      // it is the branch that always runs here. Reported in the port notes.
      expect(find.textContaining('Good morning'), findsOneWidget);
      expect(find.textContaining('there.'), findsOneWidget);
    });
  });

  group('the strap battery', () {
    testWidgets('is absent entirely when nothing has read one', (tester) async {
      await tester.pumpWidget(_header());
      await tester.pumpAndSettle();

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows the charge when there is one', (tester) async {
      await tester.pumpWidget(_header(battery: 71));
      await tester.pumpAndSettle();

      expect(find.text('71%'), findsOneWidget);
    });
  });

  group('the avatar', () {
    testWidgets('carries a ring only while a sync is running', (tester) async {
      await tester.pumpWidget(_header());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HAvatar), findsOneWidget);

      await tester.pumpWidget(_header(syncing: true));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('the greeting beside an overridden guidance', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });
    tearDown(() async => store.close());

    testWidgets('NO CHEERFUL PHRASE SITS BESIDE THE ILLNESS SENTENCE', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // The fixture's band is `high` and its guidance is the illness override,
      // which the recovery card renders verbatim.
      await reveal(tester, find.textContaining('An illness signal is active'));
      expect(find.textContaining('An illness signal is active'), findsOneWidget);
      for (final flattery in <String>[
        'Well recovered',
        'well recovered',
        'Primed',
        'PRIMED',
        'Ready to train',
      ]) {
        expect(
          find.textContaining(flattery),
          findsNothing,
          reason: 'the band is not a phrase, and the flag overrides the day',
        );
      }
    });
  });

  group('the tab bar', () {
    testWidgets('shows every tab', (tester) async {
      await tester.pumpWidget(
        host(AppTabBar(currentIndex: 0, onSelect: (_) {})),
      );
      await tester.pumpAndSettle();

      for (final tab in kAppTabs) {
        expect(find.text(tab.label), findsOneWidget);
      }
    });

    test('THE BAR CONTAINS NO DEAD CONTROL', () {
      // It used to draw Actions dimmed and inert. `core/tabs.dart` argues why a
      // navigation control that never responds is worse than four tabs; this is
      // the check that the argument stayed applied. There is no way to express a
      // routeless tab any more, so the assertion is on the list's contents.
      expect(kAppTabs.map((tab) => tab.label), <String>[
        'Today',
        'Sleep',
        'Activity',
        'Insights',
        'Actions',
      ]);
      // Coach is not among them. It is a FAB on Today and a sheet behind it,
      // which is what legacy does (`app/lib/main.dart:399`) and what
      // `docs/APP_DESIGN.md` §2 describes.
      expect(kAppTabs.map((tab) => tab.label), isNot(contains('Coach')));
    });

    test('EVERY TAB NAMES A ROUTE THE ROUTER WIRES', () {
      // The failure this guards is a tab pointing at a path nobody registered.
      // The router builds its branches from this same list, so the check is now
      // that the paths are the agreed ones rather than invented here.
      const wired = <String>{
        Routes.today,
        Routes.sleep,
        Routes.activity,
        Routes.insights,
        Routes.actions,
      };
      for (final tab in kAppTabs) {
        expect(wired, contains(tab.route), reason: '${tab.label} is a live tab');
      }
    });

    testWidgets('a tap reports its BRANCH INDEX, the active tab included', (
      tester,
    ) async {
      // Index, not route: the shell moves by branch and pressing the tab you are
      // already on is what pops that branch to its root.
      final pressed = <int>[];
      await tester.pumpWidget(
        host(AppTabBar(currentIndex: 0, onSelect: pressed.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Activity'));
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(pressed, <int>[2, 0]);
    });

    testWidgets('every tab is a button to a screen reader, the active one selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(AppTabBar(currentIndex: 1, onSelect: (_) {})),
      );
      await tester.pumpAndSettle();

      for (final tab in kAppTabs) {
        expect(find.bySemanticsLabel(tab.label), findsOneWidget);
      }
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Sleep'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });
  });
}
