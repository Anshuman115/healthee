/// A modal sheet is over the app, not over one tab — asserted as **geometry**.
///
/// The owner's report was *"the info sheet comes beyond the navbar"*. The cause
/// was the default `useRootNavigator: false`, which resolves the nearest
/// `Navigator` — the current tab's branch navigator, inside `Scaffold.body` —
/// so the sheet was laid out in the tab's content box and stopped dead at the
/// bar's top edge. `shared/sheets/app_sheet.dart` records the measurement.
///
/// **Every assertion here is a rectangle or a hit test.** Two charts on this
/// project shipped at zero height because their tests only asserted that the
/// widget existed, and a sheet whose tail is under an opaque bar is present in
/// exactly the same way. So: where is the sheet's bottom edge, what is at the
/// pixel the tab bar occupies, and where does the scroll extent end.
///
/// The last group is the sibling guard. Fixing one sheet and leaving the other
/// is how this comes back next week, so the presentation is a single function
/// and this suite reads `lib/` to prove nothing bypasses it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/today/today_screen.dart';
import 'package:healthee/shared/app_tab_bar.dart';
import 'package:healthee/shared/metric_info/metric_info.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/citation_row.dart';

import '_today_host.dart';

/// A phone with **three-button** navigation, so the bottom inset is a real
/// number rather than the zero a default test view reports.
///
/// 48 dp, not the 24 of a gesture pill, and the difference is the whole point:
/// the sheet's own foot padding is legacy's 32, which happens to clear a gesture
/// pill by itself. On the wider bar it does not, so dropping the inset actually
/// puts the sources underneath the navigation — which is what
/// `test/mutations.sh` reverts to and this suite has to catch. A fixture chosen
/// so that the bug still passes is the same as no fixture.
const double _gestureInset = 48;

/// The longest explainer in the map, so the sheet is genuinely taller than the
/// screen and its tail is a thing that has to be reached rather than a thing
/// that happens to fit.
final MapEntry<String, MetricInfo> _longest = kMetricInfo.entries.reduce(
  (a, b) =>
      (a.value.what + a.value.target + a.value.why).length >
          (b.value.what + b.value.target + b.value.why).length
      ? a
      : b,
);

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3.0
    ..viewPadding = const FakeViewPadding(top: 108, bottom: _gestureInset * 3)
    ..padding = const FakeViewPadding(top: 108, bottom: _gestureInset * 3);
  addTearDown(tester.view.reset);
}

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  /// Opens the sheet the same way a card does, from a context inside Today.
  Future<void> openInfoSheet(WidgetTester tester, {String? key}) async {
    await tester.pumpWidget(routedApp(store));
    await tester.pumpAndSettle();
    final dot = find.byType(MetricInfoDot);
    for (var i = 0; i < 25 && dot.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(dot, findsWidgets, reason: 'Today has to actually draw an ⓘ');
    if (key == null) {
      await tester.tap(dot.first, warnIfMissed: false);
    } else {
      showMetricInfo(tester.element(dot.first), key);
    }
    await tester.pumpAndSettle();
  }

  group('THE SHEET IS NOT BOUNDED BY THE TAB BAR', () {
    testWidgets('its painted bottom is the screen edge, past the bar', (
      tester,
    ) async {
      _phone(tester);
      await openInfoSheet(tester, key: _longest.key);

      final bar = tester.getRect(find.byType(AppTabBar));
      final sheet = tester.getRect(find.byType(BottomSheet));
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        bar.height,
        greaterThan(0),
        reason: 'the fixture has to have a bar for this to mean anything',
      );
      expect(
        sheet.bottom,
        moreOrLessEquals(screenHeight, epsilon: 0.5),
        reason:
            'a sheet that stops at the bar has its last line jammed against '
            'opaque chrome — this is the defect, measured',
      );
      expect(
        sheet.bottom,
        greaterThan(bar.top),
        reason: 'the sheet must reach past where the bar begins',
      );
    });

    testWidgets('the bar is behind it: a tab press does not navigate', (
      tester,
    ) async {
      _phone(tester);
      await openInfoSheet(tester, key: _longest.key);

      final bar = tester.getRect(find.byType(AppTabBar));
      // The pixel the Sleep tab occupies. With the sheet on the branch
      // navigator this hit the tab and switched the screen underneath an open
      // modal; on the root navigator the sheet is what is there.
      await tester.tapAt(Offset(bar.width * 0.3, bar.center.dy));
      await tester.pumpAndSettle();

      expect(
        find.byType(SleepScreen),
        findsNothing,
        reason: 'a modal that lets the bar navigate behind it is not modal',
      );
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('the scroll extent ends clear of the gesture inset', (
      tester,
    ) async {
      _phone(tester);
      await openInfoSheet(tester, key: _longest.key);

      final scroll = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: 'the fixture has to overflow, or there is nothing to reach',
      );

      // Scroll to the very end and look at the last thing on the sheet.
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      // The VIEWPORT's bottom edge, not the last widget's. The last widget can
      // be any of three depending on the explainer, and measuring whichever one
      // happens to be last is how a fixture stops testing the thing: the
      // question is where the scrollable region ends, because everything the
      // owner can scroll to ends there.
      final viewport = tester.getRect(scroll);
      expect(
        viewport.bottom,
        lessThanOrEqualTo(screenHeight - _gestureInset),
        reason:
            'the scroll extent must stop above the navigation bar the sheet is '
            'now painting over — otherwise the tail is occluded one inset in',
      );

      // And the sources — the last block on the sheet — are genuinely reachable
      // rather than merely constructed somewhere off screen.
      final citation = tester.getRect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(CitationRow),
        ),
      );
      expect(citation.bottom, greaterThan(0));
      expect(citation.bottom, lessThanOrEqualTo(screenHeight - _gestureInset));
    });

    testWidgets('a real ⓘ tap lands the same way', (tester) async {
      _phone(tester);
      await openInfoSheet(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      final bar = tester.getRect(find.byType(AppTabBar));
      expect(tester.getRect(find.byType(BottomSheet)).bottom, greaterThan(bar.top));
    });
  });

  group('EVERY sheet goes through the one presentation', () {
    // The sibling guard. `showModalBottomSheet` twice is two chances to get the
    // navigator wrong, and the coach sheet had the same defect with none of the
    // same symptoms reported. A source scan rather than a per-sheet test:
    // the failure mode is a sheet nobody wrote a test for.
    test('no lib/ file calls showModalBottomSheet directly', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.path.endsWith('shared/sheets/app_sheet.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains('showModalBottomSheet')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'showAppSheet is the only presentation: it pins the ROOT navigator, '
            'and a direct call defaults back to the tab branch — the bug',
      );
    });

    test('nothing turns the root navigator off', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        // The chokepoint's own docstring names the defaulted flag as the defect.
        if (entity.path.endsWith('shared/sheets/app_sheet.dart')) {
          continue;
        }
        if (entity.readAsStringSync().contains('useRootNavigator: false')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
