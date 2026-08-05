/// The loading shapes ported from `skeletons.dart`.
///
/// A skeleton is content-shaped on purpose: the screen that arrives occupies
/// exactly this space, so nothing jumps when it does. That only holds if the
/// shape keeps matching the screen, which is what the counts below are for.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/skeletons/h_skeleton.dart';
import 'package:healthee/shared/skeletons/sleep_skeleton.dart';
import 'package:healthee/shared/skeletons/today_skeleton.dart';

const HealtheeColors _light = HealtheeColors.light();

/// A host with NO width constraint, for a box that sizes itself.
Widget _tightHost(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: Center(child: child)),
);

/// Pumps a shimmering skeleton far enough that no timer is left pending.
///
/// `flutter_animate` schedules the shimmer with `Future.delayed(widget.delay)`
/// and its `dispose` does not cancel that timer, so a test that pumps one frame
/// and ends fails on "pending timers" — a real leak in the package, worked
/// around here rather than hidden. Pumping past the 250 ms delay lets it fire.
///
/// `pumpAndSettle` is not an option: the shimmer repeats forever by design, and
/// a loading state that stops moving reads as a hang.
Future<void> _pumpSkeleton(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Unmounts whatever is on screen, stopping the shimmer's ticker.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('the skeletons', () {
    testWidgets('a skeleton box fills at the recessed surface, and shimmers', (
      tester,
    ) async {
      await _pumpSkeleton(tester, _tightHost(const HSkeleton(width: 80, height: 12)));

      // The Container, not the HSkeleton: `flutter_animate` wraps the box in a
      // shader mask whose bounds are not the box's.
      expect(tester.getSize(find.byType(Container)), const Size(80, 12));
      final box = tester.widget<Container>(find.byType(Container));
      expect((box.decoration! as BoxDecoration).color, _light.surface2);
      // Legacy fills with a fourth paper tone the kept scaffolding does not
      // have; `surface2` is the substitution and it is recorded here so the
      // choice is visible rather than inferred.
      await _unmount(tester);
    });

    testWidgets('TODAY’S SKELETON IS CONTENT-SHAPED, not a spinner', (
      tester,
    ) async {
      // Tall enough that the list builds every child: a `ListView` is lazy, and
      // a skeleton nobody scrolls to is one nobody sees either.
      tester.view
        ..physicalSize = const Size(420, 1600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _pumpSkeleton(
        tester,
        MaterialApp(theme: AppTheme.light, home: const Scaffold(body: TodaySkeleton())),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Three two-up grid rows, one recovery card and one rich card — legacy's
      // shape. A skeleton that stopped matching the screen would be a jump.
      expect(find.byType(SkeletonTileRow), findsNWidgets(3));
      expect(find.byType(SkeletonRichCard), findsOneWidget);
      for (final size in tester
          .widgetList<HSkeleton>(find.byType(HSkeleton))
          .map((skeleton) => skeleton.height)) {
        expect(size, greaterThan(0));
      }
      await _unmount(tester);
    });

    testWidgets('sleep’s skeleton carries its two chart blocks at legacy’s sizes', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(420, 1600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _pumpSkeleton(
        tester,
        MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SleepSkeleton())),
      );

      final charts = tester
          .widgetList<SkeletonRichCard>(find.byType(SkeletonRichCard))
          .map((card) => card.chartHeight)
          .toList();
      expect(charts, <double>[36, 120]);
      await _unmount(tester);
    });

    testWidgets('both skeletons render in dark mode too', (tester) async {
      tester.view
        ..physicalSize = const Size(420, 1600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final body in <Widget>[const TodaySkeleton(), const SleepSkeleton()]) {
        await _pumpSkeleton(
          tester,
          MaterialApp(theme: AppTheme.dark, home: Scaffold(body: body)),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(HSkeleton), findsWidgets);
        await _unmount(tester);
      }
    });
  });
}
