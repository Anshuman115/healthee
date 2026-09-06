/// `.chapter-nav { position: sticky; top: 0 }` — reproduced, and paid for.
///
/// The prototype pins the chapter nav to the top of the page. It was skipped
/// once with an honest note ("a sticky header inside a `ListView.builder` is a
/// `SliverPersistentHeader`, which is a different scroll structure for the whole
/// screen") and that note was right about the cost and wrong about the answer.
/// `shared/instrument_screen.dart` builds that structure now.
///
/// ## The thing that had to survive the restructure
///
/// `CLAUDE.md` names it as a hard rule: *"Scrollable chart screens use
/// `ListView.builder` + reveal-once animation, or charts replay on every
/// scroll."* The guarantee is about **charts not replaying**, and the mechanism
/// is a [RevealRegistry] on the screen's `State` — it reads no scroll position,
/// no index and no viewport, so a lazy `SliverList` puts it under exactly the
/// pressure a lazy `ListView` did. `test/shared/reveal_once_test.dart` holds the
/// mechanism in isolation; the last test here holds it **in the restructured
/// screen**, which is the half that was actually at risk.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/v02/today_chapters.dart';

import '_today_host.dart';

/// The page's own scroll — the outer one. Today's chapter nav is a horizontal
/// `SingleChildScrollView` inside it, so `.first` is the ancestor.
ScrollPosition _page(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

final Finder _nav = find.byType(TodayChapterNav);

/// Where the nav sits in the scroll when it is doing nothing special.
///
/// It has to be hunted rather than measured on the first frame: the list is
/// lazy — which is the whole point of it — so the nav does not exist in the tree
/// until the viewport is near it. The walk steps forward until it appears while
/// still below the top, which is its resting place.
Future<double> _restingOffset(WidgetTester tester) async {
  final page = _page(tester);
  for (var offset = 0.0; offset <= page.maxScrollExtent; offset += 120) {
    page.jumpTo(offset);
    await tester.pumpAndSettle();
    if (_nav.evaluate().isNotEmpty) {
      final top = tester.getTopLeft(_nav).dy;
      if (top > 0) {
        return offset + top;
      }
    }
  }
  fail('the chapter nav was never built anywhere in the scroll');
}

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });

  tearDown(() => store.close());

  testWidgets('THE NAV PINS TO THE TOP AND STAYS THERE', (tester) async {
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();

    final resting = await _restingOffset(tester);

    // Far enough that the nav's resting place is well off the top.
    _page(tester).jumpTo(resting + 600);
    await tester.pumpAndSettle();

    expect(
      _nav,
      findsOneWidget,
      reason: 'a nav that scrolled away is the behaviour this replaced',
    );
    expect(
      tester.getTopLeft(_nav).dy,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: 'pinned means held at the viewport top, not merely still built',
    );
  });

  testWidgets('it is not pinned before it has been reached', (tester) async {
    // The other half of `position: sticky`: it sits in the flow until the flow
    // would carry it past the top. A header that jumped to the top on the first
    // frame would be a toolbar, which is not what the prototype draws.
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();

    final resting = await _restingOffset(tester);
    _page(tester).jumpTo(resting - 40);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(_nav).dy, moreOrLessEquals(40, epsilon: 0.5));
  });

  testWidgets('REVEAL-ONCE STILL DOES NOT REPLAY, in the sliver list', (
    tester,
  ) async {
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();

    // Off and back. `jumpTo` rather than a drag: a fling settles its own
    // ballistic simulation over many frames, which would drown the signal this
    // test reads — the number of frames the tree needs to go still.
    final page = _page(tester);
    page.jumpTo(page.maxScrollExtent);
    await tester.pumpAndSettle();
    page.jumpTo(0);

    final frames = await tester.pumpAndSettle();
    expect(
      frames,
      lessThanOrEqualTo(2),
      reason:
          'the tree took $frames frames to go still after scrolling back to '
          'charts it had already shown — a reveal replayed',
    );
  });
}
