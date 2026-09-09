/// The halo is IN the hero, it RUNS there, and it STOPS when it leaves.
///
/// `bio_halo.dart` already proves the three ways the field stops, against a
/// pumped clock and a scripted scroll position. What it cannot prove is that
/// Today wired any of it up: a hero that dropped the halo, or placed it outside
/// the scroll it watches, would pass every one of those tests.
///
/// So this suite asks the screen. The observable is **whether the tree ever goes
/// idle**, which is the one thing a running ticker changes and the one thing a
/// presence check cannot see:
///
///   * with motion allowed, `pumpAndSettle` on Today times out — something is
///     animating, and the halo is the only ambient thing on the screen;
///   * scrolled far past the hero, it settles — the field paused itself.
///
/// Every other suite in this directory pumps `todayHost` with reduced motion on
/// for exactly this reason (see its docstring). This one turns it off.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/v02/today_hero.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';
import 'package:healthee/shared/v02/instruments/bio_halo.dart';
import 'package:healthee/shared/v02/summary_tile.dart';

import '../_today_stubs.dart';
import '_today_host.dart';

/// Whether the tree reaches idle inside a second.
///
/// `pumpAndSettle` throws on a timeout and both it and `expectLater` are guarded
/// against overlapping, so the throw is caught here rather than matched — see
/// `test_async_utils.dart`. A `bool` is also the thing the assertion is about.
Future<bool> _settles(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 33),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 1),
    );
    return true;
  }
  // `pumpAndSettle`'s timeout IS a `FlutterError`, and that timeout is the
  // observation this helper exists to make. There is no exception form of it
  // to catch instead, and catching `Object` would swallow a real failure.
  // ignore: avoid_catching_errors
  on FlutterError {
    return false;
  }
}

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  /// A phone-sized viewport, so the hero can actually be scrolled off it.
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Tall enough that the `ListView.builder` builds the whole port in one pass.
  void tall(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(420, 14000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('THE HALO IS INSIDE THE HERO, NOT BESIDE IT', (tester) async {
    phone(tester);
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();

    expect(find.byType(BioHero), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BioHero), matching: find.byType(BioHalo)),
      findsOneWidget,
      reason: 'the ring belongs around the figure, not somewhere near it',
    );
    // And it is the card's art, so it is behind the number rather than over it:
    // the figure is laid out inside the halo's own box.
    final halo = tester.getRect(find.byType(BioHalo));
    final figure = tester.getRect(find.text('34.3'));
    expect(halo.contains(figure.center), isTrue);
  });

  testWidgets('IT RUNS ON SCREEN, AND PAUSES WHEN IT SCROLLS AWAY', (
    tester,
  ) async {
    // The observable is whether the tree can ever go idle. A 30 fps ambient
    // field makes `pumpAndSettle` time out, and nothing else on Today animates
    // forever — every other reveal is once-and-done. So: it must NOT settle
    // while the hero is on screen, and it must settle once the hero is not.
    //
    // That is a stronger check than "a ticker exists", which is true of the
    // pull-to-refresh indicator too.
    phone(tester);
    await tester.pumpWidget(todayHost(store, reducedMotion: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      await _settles(tester),
      isFalse,
      reason: 'the halo is not ticking, so the hero is a still image',
    );

    // Off screen: the field watches the enclosing scroll and stops itself.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pump();

    expect(
      await _settles(tester),
      isTrue,
      reason: 'a halo that keeps ticking off screen is 30 fps of nothing',
    );
  });

  testWidgets('REDUCED MOTION STOPS IT DEAD, ON THE REAL SCREEN', (
    tester,
  ) async {
    // The accessibility path, asked of the screen rather than of the widget:
    // under reduced motion the tree SETTLES, which a live 30 fps field makes
    // impossible. Every other suite in this directory depends on it.
    phone(tester);
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();

    expect(find.byType(BioHalo), findsOneWidget);
  });

  group('what the hero says about the estimate', () {
    testWidgets('the figure, the delta and the two terms are the server’s', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      expect(find.text('34.3'), findsOneWidget);
      expect(
        find.textContaining('below your chronological age of'),
        findsOneWidget,
      );
      // The model line is ALWAYS reachable: an estimate that does not say what
      // made it is the failure the whole tier system exists to stop. It moved
      // off the card into the eyebrow's ⓘ, so this opens the ⓘ and reads it
      // there — the claim is that the owner can get to the sentence, not that
      // it is printed in nine-point grey under the contributions.
      expect(find.byType(BioModelLabel), findsNothing);
      final model = tester.widget<BioHero>(find.byType(BioHero)).modelLabel!;
      await tester.tap(
        find.descendant(
          of: find.byType(BioHero),
          matching: find.byType(MetricInfoDot),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(model), findsOneWidget);
    });

    testWidgets('NO DELTA MEANS NO SENTENCE ABOUT ONE', (tester) async {
      // Rather than "0.0 years below" about an age nothing compared.
      phone(tester);
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'biological_age': <String, Object?>{
                ...json['biological_age']! as Map<String, Object?>,
                'delta_years': null,
                'chronological_age': null,
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('34.3'), findsOneWidget);
      expect(find.textContaining('chronological age'), findsNothing);
    });
  });

  group('the three summary tiles', () {
    testWidgets('A TILE WITH NO READING IS NAMED, HELD AND VISIBLY EMPTY', (
      tester,
    ) async {
      // Never a blank and never a zero: `—` with `Not measured` under it, in a
      // tile that keeps its slot so the row does not change shape.
      tall(tester);
      await tester.pumpWidget(
        todayHost(
          store,
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'metrics': const <Object?>[],
              'recovery_score': null,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tiles = find.byType(SummaryTile);
      expect(tiles, findsNWidgets(3));
      expect(
        find.descendant(of: tiles, matching: find.text('Not measured')),
        findsWidgets,
      );
      expect(find.byType(TodaySummaryTiles), findsOneWidget);
    });

    testWidgets('NO TARGET MEANS NO METER — never a bar against a guess', (
      tester,
    ) async {
      // `/api/today` carries no step target, so the movement tile draws its
      // number and nothing to read it against.
      tall(tester);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      final movement = find.byWidgetPredicate(
        (widget) => widget is SummaryTile && widget.title == 'Movement',
      );
      expect(movement, findsOneWidget);
      expect(tester.widget<SummaryTile>(movement).fraction, isNull);
      expect(
        find.descendant(of: movement, matching: find.byType(TileMeter)),
        findsNothing,
      );
    });
  });
}
