/// **Today does not print the server's caveat essays, and does not swallow them.**
///
/// The owner, on the installed build: *"below the fitness card there is some
/// bullet points in raw text i dont think thats needed to be shown there"* and
/// *"Respiratory rate text is too big which makes the card too big"*. One defect,
/// two symptoms — every disclosure was rendered in full, inline, under whatever
/// drew the value.
///
/// This file asserts against **the committed contract snapshot's own strings**,
/// not against a fixture written to match the fix. That matters twice over: the
/// lengths below are the real wire (`biological_age` alone carries four
/// disclosures totalling ~2,780 characters), and a server that shortened them
/// would not quietly make this suite vacuous — the premise test fails first and
/// says so.
///
/// The two halves are equally load-bearing and the second is the dangerous one:
///
///   * the prose is **not on the screen**, so the screen is short again;
///   * the disclosure is **still on the screen**, in words, and the prose is one
///     tap behind it. A caveat that became invisible would be a worse failure
///     than the essay, because nothing would look wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/today/widgets/blood_oxygen_card.dart';
import 'package:healthee/features/today/widgets/metric_tile.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';

import '../_today_stubs.dart';
import '_today_host.dart';

/// Every caveat and exclusion sentence the snapshot attaches to a REPORTED value.
///
/// `envelope.dart` folds `excluded` in beside `caveats` when a value arrived —
/// those disclosures narrow a number that still exists — so both lists are what
/// a caveat carrier has to hold.
List<String> _attachedMessages(Map<String, Object?> block) => <String>[
  for (final key in const ['caveats', 'excluded'])
    for (final entry in (block[key] as List<Object?>? ?? const <Object?>[]))
      (entry! as Map<String, Object?>)['message']! as String,
];

/// The longest run of characters a card may print without being asked.
///
/// Not a style budget — a diagnosis. Everything the fix removed is far above it
/// and everything it kept is far below, so a value in between would mean
/// something new landed on the card and nobody looked.
const int _essayLength = 300;

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  Future<void> openToday(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(420, 14000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();
  }

  test('THE PREMISE — the wire really does attach essays to a shown number', () {
    // If this fails, the server got shorter and this whole suite needs re-reading
    // rather than deleting: the carrier is still right, the pressure is gone.
    final bio =
        loadTodayJson()['biological_age']! as Map<String, Object?>;
    final messages = _attachedMessages(bio);

    expect(bio['biological_age'], isNotNull, reason: 'a value IS reported');
    expect(messages, hasLength(4));
    expect(
      messages.fold<int>(0, (sum, message) => sum + message.length),
      greaterThan(2500),
    );
    expect(messages.every((message) => message.length > _essayLength), isTrue);
  });

  testWidgets('NO SERVER CAVEAT PROSE IS RENDERED INLINE ON TODAY', (
    tester,
  ) async {
    await openToday(tester);

    final bio = loadTodayJson()['biological_age']! as Map<String, Object?>;
    for (final message in _attachedMessages(bio)) {
      expect(
        find.text(message),
        findsNothing,
        reason: 'this is what the owner saw:\n${message.substring(0, 90)}…',
      );
      // Not just the whole string — a card that printed the first sentence of
      // an essay would still be an essay's worth of card.
      expect(find.textContaining(message.substring(0, 60)), findsNothing);
    }
  });

  testWidgets('NOTHING ON TODAY PRINTS AN ESSAY UNASKED', (tester) async {
    // The general form, so the next long sentence the server grows is caught by
    // the same test rather than by the owner.
    await openToday(tester);

    final long = <String>[
      for (final widget in tester.widgetList<Text>(find.byType(Text)))
        if ((widget.data ?? '').length > _essayLength) widget.data!,
    ];
    expect(
      long,
      isEmpty,
      reason: 'Today printed ${long.length} run(s) over $_essayLength chars, '
          'the first being:\n${long.isEmpty ? '' : long.first}',
    );
  });

  testWidgets('THE CAVEATED VALUES STILL DISCLOSE, IN WORDS', (tester) async {
    // The half that keeps the compaction honest. Today carries three caveated
    // readings on this payload — biological age (4 disclosures), and the Resp
    // tile and blood-oxygen module, both fed from `last_sleep_extras` with the
    // sentence naming the instrument.
    await openToday(tester);

    expect(
      find.byType(CaveatNote),
      findsWidgets,
      reason: 'the signpost under a card',
    );
    expect(
      find.byType(CaveatFoot),
      findsWidgets,
      reason: 'the counted line in a grid tile’s foot',
    );
    expect(find.text(caveatHeadline(4)), findsOneWidget);
  });

  testWidgets('BIOLOGICAL AGE — ALL FOUR DISCLOSURES ARE ONE TAP AWAY, IN FULL', (
    tester,
  ) async {
    // The card the owner named. Its signpost has to open every one of them: a
    // sheet that showed the first paragraph would be the same failure in a
    // smaller box, and the count on the card would be lying about its contents.
    await openToday(tester);
    await reveal(tester, find.text(caveatHeadline(4)));

    await tester.tap(find.text(caveatHeadline(4)));
    await tester.pumpAndSettle();

    expect(find.text(kCaveatSheetTitle), findsOneWidget);
    final bio = loadTodayJson()['biological_age']! as Map<String, Object?>;
    final messages = _attachedMessages(bio);
    expect(messages, hasLength(4));
    for (final message in messages) {
      expect(
        find.text(message),
        findsOneWidget,
        reason: 'missing from the sheet:\n${message.substring(0, 70)}…',
      );
    }
  });

  testWidgets('THE RESP TILE DISCLOSES, AND THE PROSE OPENS FROM IT', (
    tester,
  ) async {
    await openToday(tester);
    await reveal(tester, find.text('RESPIRATORY RATE'));

    final tile = find.ancestor(
      of: find.text('RESPIRATORY RATE'),
      matching: find.byType(MetricTile),
    );
    final mark = find.descendant(of: tile, matching: find.byType(CaveatFoot));
    expect(mark, findsOneWidget, reason: 'the tile must say it is caveated');
    // IN WORDS, and counted — the whole point of replacing the `*`.
    expect(
      find.descendant(of: tile, matching: find.text('1 CAVEAT · TAP TO READ')),
      findsOneWidget,
    );
    // Visible, not merely mounted.
    expect(tester.getSize(mark).height, greaterThan(0));
    expect(tester.getSize(mark).width, greaterThan(0));

    await tester.tap(mark);
    await tester.pumpAndSettle();

    expect(find.text(kCaveatSheetTitle), findsOneWidget);
    expect(find.textContaining('plain average'), findsOneWidget);
    expect(find.textContaining('not today'), findsOneWidget);
  });

  testWidgets('THE RESP TILE IS THE SAME HEIGHT AS THE SLEEP TILE BESIDE IT', (
    tester,
  ) async {
    // The owner's second report, measured. Both cells are in one `MetricTileRow`
    // whose cross-alignment is legacy's `start`, so a taller cell does not
    // stretch its neighbour — it just stands proud of it, which is what a grid
    // is not allowed to do.
    await openToday(tester);
    await reveal(tester, find.text('RESPIRATORY RATE'));

    final resp = find.ancestor(
      of: find.text('RESPIRATORY RATE'),
      matching: find.byType(MetricTile),
    );
    final sleep = find.ancestor(
      of: find.text('SLEEP'),
      matching: find.byType(MetricTile),
    );
    expect(sleep, findsOneWidget);
    expect(
      tester.getSize(resp).height,
      tester.getSize(sleep).height,
      reason: 'a tile that grows to fit prose breaks the grid',
    );
  });

  testWidgets('EVERY GRID TILE THAT REPORTS A NUMBER IS THE SAME HEIGHT', (
    tester,
  ) async {
    // The row-by-row version would pass with all six wrong together. This one
    // asks the question the owner actually asked of the screen.
    //
    // **A WITHHELD cell is excluded, and deliberately.** `metric_tile.dart`'s
    // `_Hole` takes a floor rather than a fixed height because legacy gives
    // these six metrics no detail screen to point at, so a cell that said only
    // WITHHELD would be a refusal with no explanation anywhere on the device.
    // That is a documented exception with a reason; a caveated cell is not one,
    // because its value IS being shown and the detail HAS somewhere to live.
    await openToday(tester);
    await reveal(tester, find.text('RESPIRATORY RATE'));

    final tiles = tester.widgetList<MetricTile>(find.byType(MetricTile)).toList();
    final reported = <double>[
      for (var i = 0; i < tiles.length; i++)
        if (tiles[i].reading.hasValue)
          tester.getSize(find.byType(MetricTile).at(i)).height,
    ];
    expect(reported.length, greaterThanOrEqualTo(4));
    expect(reported.toSet(), hasLength(1), reason: 'saw heights $reported');
  });

  testWidgets('THE BLOOD-OXYGEN MODULE STOPPED SWALLOWING ITS CAVEAT', (
    tester,
  ) async {
    // Found while fixing the above and worth its own test: this card renders its
    // figure through `TrailingReading`, which draws a number or a hole and has no
    // room for a disclosure. So a caveated SpO₂ — which is what this payload
    // sends — showed the number with the tilt on it dropped in silence. That is
    // the failure mode `Caveated` is a separate case in order to prevent, and it
    // was live.
    await openToday(tester);
    await reveal(tester, find.byType(BloodOxygenCard));

    final module = find.descendant(
      of: find.byType(BloodOxygenCard),
      matching: find.byType(InstrumentModule),
    );
    expect(
      find.descendant(of: module, matching: find.byType(CaveatNote)),
      findsOneWidget,
    );
  });
}
