/// **A caveat is attached to a number, or it is a claim about the wrong one.**
///
/// Two owner reports of 2026-08-06, one screen apart, and they are the same
/// defect seen from two sides:
///
///   * *"what are those * symbol in card"* — `CaveatMark` drew a bare asterisk
///     and nothing on the screen said what it meant. The file it lived in states
///     in its own docstring that a caveated value discloses **in words**; an
///     asterisk is not words, and only a reader who had opened that file could
///     have known.
///   * *"the caveat is sitting and its difficutlt to understand which caveat is
///     that pointing to"* — `ReadingView` drew the signpost as a SIBLING beneath
///     whatever its builder returned. On a screen of cards that put the sentence
///     in the **gutter**, closer to the card below it than to the one it
///     qualifies.
///
/// The second is the dangerous one. A disclosure attached to the wrong number is
/// not a weaker disclosure, it is a **misattributed** one: it can read as
/// qualifying a figure that is in fact unqualified, which is a new false claim
/// produced entirely by layout. `shared/states/caveat_scope.dart` carries the
/// fix; this file is the guard on it, and it is deliberately geometric rather
/// than structural — "the carrier is mounted" was already true while the owner
/// was looking at the bug.
///
/// It runs on **every screen that draws a caveated reading**, because the fix is
/// per-carrier and the orphaning was per-call-site.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/panel.dart';

import '../_sleep_stubs.dart';
import '_today_host.dart';

/// Whether [text] is a lone footnote glyph with no word attached.
///
/// Punctuation only, and short: `*` is the one the owner asked about, and
/// `†`/`‡` are the two a future author would reach for next.
bool isBareMark(String text) {
  final trimmed = text.trim();
  return trimmed.isNotEmpty &&
      trimmed.length <= 2 &&
      trimmed.split('').every((rune) => '*†‡'.contains(rune));
}

/// Every rect a caveat carrier occupies on the pumped screen.
List<Rect> _carriers(WidgetTester tester) => <Rect>[
  for (final type in <Finder>[find.byType(CaveatNote), find.byType(CaveatFoot)])
    for (var i = 0; i < tester.widgetList(type).length; i++)
      tester.getRect(type.at(i)),
];

/// Every rect a CARD occupies — the bounds a carrier has to be inside.
List<Rect> _cards(WidgetTester tester) => <Rect>[
  for (final type in <Finder>[
    find.byType(StateCard),
    find.byType(InstrumentModule),
    // v02's two carriers. `Panel` and `BioHero` read the same `CaveatScope`
    // that `InstrumentModule` does, so a Today card is measured the same way a
    // Sleep card is.
    find.byType(Panel),
    find.byType(BioHero),
  ])
    for (var i = 0; i < tester.widgetList(type).length; i++)
      tester.getRect(type.at(i)),
];

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  /// Pumps [home] tall enough that every card is laid out in one pass.
  ///
  /// A `ListView.builder` never builds a card it has not scrolled to, and a card
  /// that was never built cannot be measured — which would make this suite pass
  /// by seeing nothing.
  Future<void> pump(WidgetTester tester, Widget? home) async {
    tester.view
      ..physicalSize = const Size(420, 14000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(todayHost(store, home: home));
    await tester.pumpAndSettle();
  }

  final screens = <String, Widget?>{
    'Today': null,
    'Sleep': SleepScreen(now: kSleepNow),
    'Activity': const ActivityScreen(),
  };

  for (final screen in screens.entries) {
    group(screen.key, () {
      testWidgets('NO BARE `*` REACHES THE SCREEN', (tester) async {
        await pump(tester, screen.value);

        final bare = <String>[
          for (final widget in tester.widgetList<Text>(find.byType(Text)))
            if (isBareMark(widget.data ?? '')) widget.data!,
        ];
        expect(
          bare,
          isEmpty,
          reason: '${screen.key} rendered ${bare.length} unlabelled mark(s): '
              '$bare',
        );
      });

      testWidgets('IT REALLY DOES CARRY CAVEATED READINGS', (tester) async {
        // Without this the two assertions around it pass on a screen that has
        // no disclosures to place, which is the shape of a vacuous suite — and
        // it is exactly how a carrier that stopped drawing its note would slip
        // through: nothing would be misplaced, because nothing would be there.
        await pump(tester, screen.value);

        expect(
          _carriers(tester),
          isNotEmpty,
          reason: '${screen.key} draws no caveat carrier at all',
        );
      });

      testWidgets('EVERY CAVEAT CARRIER IS INSIDE THE CARD IT IS ABOUT', (
        tester,
      ) async {
        await pump(tester, screen.value);

        final cards = _cards(tester);
        for (final carrier in _carriers(tester)) {
          expect(
            cards.any(
              (card) =>
                  card.contains(carrier.topLeft) &&
                  card.contains(carrier.bottomRight - const Offset(0.5, 0.5)),
            ),
            isTrue,
            reason: 'a caveat carrier at $carrier is in the gutter between two '
                'cards, not inside the one whose number it qualifies',
          );
        }
      });
    });
  }

  testWidgets('THE PREMISE — Today really does carry caveated readings', (
    tester,
  ) async {
    // Without this the two assertions above pass on a screen that has no
    // disclosures to place, which is the shape of a vacuous suite. The
    // biological-age block of the committed snapshot carries four.
    await pump(tester, null);
    expect(_carriers(tester), isNotEmpty);
    expect(find.text(caveatHeadline(4)), findsOneWidget);
  });
}
