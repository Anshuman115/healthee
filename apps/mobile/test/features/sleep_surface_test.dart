/// What reaches the Sleep screen's surface, and what must never reach it.
///
///   * **no raw `snake_case` id and no `[` marker on any surface** — the whole
///     screen is scrolled and every string on it is read;
///   * `naps[].stages` is asserted to be the always-empty field it is, so nobody
///     builds a section on it believing it can have content;
///   * `findings` draws nothing when it is empty, and something when it is not;
///   * and the screen lays out at four phone widths, none of them 800.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/sleep/v02/naps_panel.dart';
import 'package:healthee/shared/charts/v02/v02_stage_strip.dart';
import 'package:healthee/shared/findings_section.dart';

import '../_sleep_stubs.dart';
import '_sleep_host.dart';
import '_today_host.dart';

/// A `snake_case` word of the kind a research-note id or a metric key is.
final RegExp _rawId = RegExp(r'\b[a-z][a-z0-9]*(_[a-z0-9]+){2,}\b');

/// Every string the widget tree is currently rendering.
List<String> _renderedText(WidgetTester tester) => <String>[
  for (final widget in tester.allWidgets)
    if (widget is Text)
      widget.data ?? widget.textSpan?.toPlainText() ?? ''
    else if (widget is RichText)
      widget.text.toPlainText(),
];

void main() {
  late LocalStore store;

  setUpAll(loadSleepFont);
  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('nothing raw reaches a surface', () {
    testWidgets('NO snake_case ID AND NO [ MARKER, ANYWHERE ON THE SCREEN', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        todayHost(store, home: SleepScreen(now: kSleepNow)),
      );
      await tester.pumpAndSettle();

      // Scrolled to the bottom, because a lazy list has not built what is off
      // screen and an id could be hiding in any of it.
      for (var pass = 0; pass < 12; pass++) {
        for (final text in _renderedText(tester)) {
          expect(
            _rawId.hasMatch(text),
            isFalse,
            reason: 'a raw id reached the screen: "$text"',
          );
          expect(
            text,
            isNot(contains('[')),
            reason: 'an unresolved citation marker reached the screen: "$text"',
          );
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
    });
  });

  group('naps', () {
    test('naps[].stages is ALWAYS EMPTY, and that is a server-side shape bug', () {
      // Recorded rather than worked around. `read/sleep_page.py` ships the raw
      // JSONB hypnogram for a nap — `[[startMs, endMs, typeCode]]` — where
      // `nights` ships `stage_timeline()`'s objects, so `NapStage.fromJson`
      // never sees a map and a nap's stage list is empty on every payload.
      //
      // A client-side fix would mean re-implementing the strap's stage-code
      // mapping in the UI layer, i.e. a second definition of what a stage is.
      final raw = loadJson(kSleepSnapshotPath);
      final naps = raw['naps']! as List<Object?>;
      expect(naps, isNotEmpty);
      for (final nap in naps.cast<Map<String, Object?>>()) {
        for (final span in nap['stages']! as List<Object?>) {
          expect(
            span,
            isNot(isA<Map<String, Object?>>()),
            reason: 'if this passes maps now, the server was fixed — drop this',
          );
        }
      }
      for (final nap in sleepPageFixture().naps) {
        expect(nap.stages, isEmpty);
      }
    });

    testWidgets('SO THE PANEL DRAWS NO BAR, AND SAYS WHY IN WORDS', (
      tester,
    ) async {
      // An empty bar is a picture of a measurement that does not exist.
      await tester.pumpWidget(
        sleepPanelHost(NapsPanel(naps: sleepPageFixture().naps)),
      );
      await tester.pumpAndSettle();

      expect(find.text(kNapStagesNote), findsOneWidget);
      // And nothing in the panel is a stage strip.
      expect(
        find.descendant(
          of: find.byType(NapsPanel),
          matching: find.byType(V02StageStrip),
        ),
        findsNothing,
      );
    });

    testWidgets('a day with no nap says so rather than drawing an empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        sleepPanelHost(const NapsPanel(naps: <SleepNap>[])),
      );
      await tester.pumpAndSettle();
      expect(find.text(kNoNapsNote), findsOneWidget);
    });
  });

  group('findings — the section that must not exist when it is empty', () {
    test('AN EMPTY FINDINGS ARRAY DRAWS NOTHING — no heading, no zero-state', () {
      // The governing rule for everything surfaced off the new API. Sleep
      // findings are empty for most owners most of the time (`read/findings.py`
      // returns `[]` whenever the analytics layer has nothing), so a section
      // that always existed would usually exist to say it was empty.
      final page = sleepPageFixture();
      final types = sectionTypes(
        sleepList(
          page: SleepPage(
            nights: page.nights,
            naps: page.naps,
            cutoffs: page.cutoffs,
            findings: const [],
            researchNotes: page.researchNotes,
          ),
        ),
      );
      expect(types, isNot(contains(FindingsSection)));
      // MUTATION — and the same payload WITH a finding does draw one, so this
      // is not passing because the section was never wired.
      expect(sectionTypes(sleepList()), contains(FindingsSection));
    });
  });

  group('the screen lays out on a phone, and never at 800', () {
    for (final width in kSleepWidths) {
      testWidgets('no overflow at $width', (tester) async {
        tester.view
          ..physicalSize = Size(width, 2400)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          todayHost(store, home: SleepScreen(now: kSleepNow)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (var pass = 0; pass < 10; pass++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'overflow at $width');
        }
      });
    }
  });
}
