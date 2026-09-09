/// The editorial head of Today: legacy's greeting header, and the tab bar.
///
/// The header is v02's `H.header('Today', …)` — the date, the screen's name,
/// and the avatar with its sync ring — plus the `.device-strip` under it. The
/// tests here hold the things about them that are claims rather than layout:
/// the date table has no off-by-one, the strap's charge appears only when one
/// has been read, and **no cheerful phrase sits beside a safety sentence**.
///
/// That last one is why the header says `Today` and nothing else. The pre-v02
/// header opened with a two-line greeting and the obvious next step was to
/// derive a phrase from `recovery_score.band`. The contract snapshot is exactly
/// the case that makes it a bug: `band: "high"` beside guidance that begins
/// "An illness signal is active". v02 removes the salutation outright, which
/// settles it — but the assertion stays, because the band is still on the wire.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/tabs.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/app_tab_bar.dart';
import 'package:healthee/shared/connection/sync_ring.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';

import '_today_host.dart';

/// One widget in the light theme.
Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

Widget _header({
  String date = '2026-08-06',
  DateTime? at,
  ConnectionHealth? health,
}) => host(
  TodayHeader(date: date, now: at ?? DateTime(2026, 8, 6, 9), health: health),
);

/// The device strip, which is where the strap's charge lives in v02.
Widget _strip({int? battery, ConnectionHealth? health}) =>
    host(DeviceStrip(batteryPercent: battery, health: health));

/// One classification, from a real link. There is no `syncing` flag any more:
/// the ring reads `busy` off the same object the card reads its faults off.
ConnectionHealth _connection(StrapConnection link) =>
    connectionHealth(link: link, now: DateTime(2026, 8, 6, 9), signedIn: true);

void main() {
  group('the date eyebrow', () {
    testWidgets("abbreviates the day and month, as legacy's does", (
      tester,
    ) async {
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

  group('the screen names itself', () {
    testWidgets('the h1 is the screen, not a salutation', (tester) async {
      await tester.pumpWidget(_header());
      await tester.pumpAndSettle();

      // The prototype's README: *"replaces generic main-screen slogans with
      // direct labels such as Today, Sleep, Activity"*. The pre-v02 header's
      // largest type was a greeting to an owner whose name nothing stores.
      expect(find.text(TodayHeader.title), findsOneWidget);
      expect(find.textContaining('Good morning'), findsNothing);
      expect(find.textContaining('there.'), findsNothing);
    });
  });

  group('the strap battery', () {
    testWidgets('is absent entirely when nothing has read one', (tester) async {
      await tester.pumpWidget(_strip());
      await tester.pumpAndSettle();

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows the charge when there is one', (tester) async {
      await tester.pumpWidget(_strip(battery: 71));
      await tester.pumpAndSettle();

      expect(find.text('71%'), findsOneWidget);
    });

    testWidgets('THE DOT IS GREEN ONLY WHEN THE LINK IS QUIET', (tester) async {
      // A green dot beside a strap nobody has heard from is the flattery this
      // product exists not to do, so the classification decides it.
      await tester.pumpWidget(_strip());
      await tester.pumpAndSettle();

      expect(find.byType(DeviceStrip), findsOneWidget);
      expect(find.text(DeviceStrip.deviceName), findsOneWidget);
      expect(find.text(DeviceStrip.action), findsOneWidget);
    });
  });

  group('the avatar', () {
    testWidgets('carries no ring when nothing has classified a link', (
      tester,
    ) async {
      await tester.pumpWidget(_header());
      await tester.pumpAndSettle();

      expect(find.byType(SyncRing), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HAvatar), findsOneWidget);
    });

    testWidgets('draws the ring once there IS a classification', (
      tester,
    ) async {
      await tester.pumpWidget(
        _header(health: _connection(Connected(since: DateTime(2026, 8, 6, 9)))),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(HAvatar), findsOneWidget);
    });

    testWidgets('THE DATE ROW CARRIES NO SECOND MARK', (tester) async {
      // The 7 px dot went with the strip. Two marks for one fact was the whole
      // argument for the dot's existence, and it cuts both ways — the ring says
      // `live` and `idle` in the same colours, eight pixels to the right.
      await tester.pumpWidget(
        _header(health: _connection(Connected(since: DateTime(2026, 8, 6, 9)))),
      );
      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'exactly one mark in this row reports the connection',
      );
    });
  });

  group('the header beside an overridden guidance', () {
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
      expect(
        find.textContaining('An illness signal is active'),
        findsOneWidget,
      );
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
        expect(
          wired,
          contains(tab.route),
          reason: '${tab.label} is a live tab',
        );
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

    testWidgets(
      'every tab is a button to a screen reader, the active one selected',
      (tester) async {
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
      },
    );
  });
}
