/// Actions, rebuilt to the prototype — its order, its geometry, its honesty.
///
/// The order case asks the **builder** rather than a scroll position, for the
/// reason `_screen_data.dart` gives: order is a decision, and scrolling a list
/// until something appears asserts what happened to be on screen when the drag
/// stopped.
///
/// Everything else is a rectangle or a string that must not exist. Two charts on
/// this project shipped at zero height because their tests asserted only that a
/// widget was there, so a card's ground, a checkbox's box and a row's right edge
/// are measured rather than found.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/actions/actions_screen.dart';
import 'package:healthee/features/actions/v02/suggestion_card.dart';
import 'package:healthee/features/actions/v02/suggestion_list.dart';
import 'package:healthee/features/actions/v02/suggestion_row.dart';
import 'package:healthee/features/actions/v02/working_on.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/format/other_day.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/screen_head.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/surfaces.dart';

import '../_today_stubs.dart';
import '../shared/_decoration.dart';
import '_screen_data.dart';
import '_today_host.dart';

/// A one-word name for each section, so the order reads as the prototype's.
String _id(PageSection section) => switch (section.child) {
  ScreenHead() => 'head',
  SuggestionList() => 'suggestions',
  LoadingState() => 'pending',
  SectionHead(:final title) => 'section:$title',
  WorkingOn() => 'working-on',
  RowCard() => 'rows',
  DataFooter() => 'footer',
  PanelNote() => 'note',
  final Widget other => other.runtimeType.toString(),
};

/// The `logs_summary`-free recommendation set, re-dated to [day].
Map<String, Object?> Function(Map<String, Object?>) _recsDated(String day) =>
    (json) => <String, Object?>{
      ...json,
      'recommendations': <Object?>[
        for (final row in json['recommendations']! as List<Object?>)
          <String, Object?>{...row! as Map<String, Object?>, 'date': day},
      ],
    };

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('C5 · THE SET NAMES ITS OWN DAY WHEN IT IS NOT THIS ONE', () {
    // `read/today.py` reaches two days back for the newest recommendation set. Today's
    // card has said "written for <day>" about that since A3; this screen relabelled the
    // identical rows with the VIEWED day and its `SuggestionCard` never read `rec.date`.
    // Same class as A4, third instance, and the fix was in the file next door.
    test('a two-day-stale set is captioned, above the cards', () {
      final sections = actionsSections(
        screenData(server: todayView(mutate: _recsDated('2026-07-29'))),
        const ActionsLinks(),
      );

      final ids = sections.map(_id).toList();
      expect(
        ids.indexOf('note'),
        1,
        reason: 'the caption qualifies the whole set',
      );
      expect(ids.indexOf('note'), lessThan(ids.indexOf('suggestions')));

      final note = sections[1].child as PanelNote;
      expect(note.text, writtenForDay('2026-07-29'));
    });

    test('a set written for the day on screen is captioned with nothing', () {
      final ids = actionsSections(
        screenData(server: todayView()),
        const ActionsLinks(),
      ).map(_id).toList();

      expect(ids.contains('note'), isFalse);
    });

    test('an empty set has no day to name', () {
      final ids = actionsSections(
        screenData(
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'recommendations': const <Object?>[],
            },
          ),
        ),
        const ActionsLinks(),
      ).map(_id).toList();

      expect(ids.contains('note'), isFalse);
      // The list is still built for an empty set: it draws the ring that counts
      // the set — `0/0` — and says the day was quiet beside it. A screen that
      // dropped the whole block would drop the count with it.
      expect(ids[1], 'suggestions');
    });
  });

  group('THE PROTOTYPE’S SECTIONS, IN THE PROTOTYPE’S ORDER', () {
    test('the five blocks of screens-actions.js, in order', () {
      final ids = actionsSections(
        screenData(server: todayView()),
        const ActionsLinks(),
      ).map(_id).toList();

      expect(ids, <String>[
        'head',
        'suggestions',
        // No `SectionHead` above it: `WorkingOn` draws its own heading with its
        // content, so a scope with nothing running takes its title with it
        // rather than leaving a heading over an absence.
        'working-on',
        'section:$kRecordHeading',
        'rows',
        'footer',
      ]);
    });

    test('a quiet day says so and still offers everything after it', () {
      final sections = actionsSections(
        screenData(
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'recommendations': const <Object?>[],
            },
          ),
        ),
        const ActionsLinks(),
      );
      final ids = sections.map(_id).toList();

      // The block stays and says the day was quiet — see `SuggestionList`.
      expect(ids[1], 'suggestions');
      expect(
        sections[1].child,
        isA<SuggestionList>().having(
          (list) => list.recommendations,
          'recommendations',
          isEmpty,
        ),
      );
      // The rest of the screen is unchanged: an absent suggestion is not an
      // absent screen.
      expect(ids.last, 'footer');
      expect(ids.contains('working-on'), isTrue);
    });

    test('every rank the server sent reaches the list, in its order', () {
      final sections = actionsSections(
        screenData(
          server: todayView(
            mutate: (json) => <String, Object?>{
              ...json,
              'recommendations': <Object?>[
                ...(json['recommendations']! as List<Object?>),
                <String, Object?>{
                  'id': 10344,
                  'action': 'Walk after dinner',
                  'category': 'activity',
                  'evidence_grade': 2,
                  'research_note_ids': const <String>['steps_mortality'],
                },
              ],
            },
          ),
        ),
        const ActionsLinks(),
      );
      // One `SuggestionList` holds the whole set now, where there was a
      // `SuggestionCard` section per recommendation. What must not change is
      // that the server's ORDER survives: the ranking is the server's claim
      // about which suggestion matters most today, and a client that re-sorted
      // it would be overruling that silently.
      final lists = sections
          .map((section) => section.child)
          .whereType<SuggestionList>()
          .toList();
      expect(lists.length, 1);
      expect(
        lists.single.recommendations.map((rec) => rec.action).toList(),
        <String>[
          screenData(server: todayView()).snapshot!.recommendations.first.action,
          'Walk after dinner',
        ],
      );
    });
  });

  group('the suggestion card', () {
    testWidgets(
      'ITS COLOUR IS THE CATEGORY’S FAMILY, NOT A COLOUR IT WAS GIVEN',
      (tester) async {
        await tester.pumpWidget(
          todayHost(store, home: ActionsScreen(now: now)),
        );
        await tester.pumpAndSettle();

        const hues = InstrumentHues.light();
        // The row's ground is the plain card surface now — the category speaks
        // through the CONTROL instead, which is where the owner asked for it:
        // "lets use color coded button please". So the assertion moved to the
        // button, and it is still the same claim — the hue is derived from the
        // category the server sent, never handed to the card by its caller.
        final button = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(HButton).first,
                matching: find.byType(Container),
              )
              .first,
        );
        // The fixture's one recommendation is `category: sleep`.
        expect(groundOf(button.decoration!), Tone.sleep.family(hues));
        expect(
          groundOf(button.decoration!),
          isNot(Tone.fitness.family(hues)),
          reason: 'a card that ignored the category would be the root default',
        );
      },
    );

    testWidgets('ITS CONTROL SAYS INTENTION, NEVER COMPLETION', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: ActionsScreen(now: now)));
      await tester.pumpAndSettle();

      // **The 24 × 24 checkbox is gone.** It read as a completion tick — the
      // one thing this app cannot observe — and the owner asked for a
      // colour-coded button in its place. The words are what carry the meaning
      // now, so the words are what this pins.
      expect(find.byType(HButton), findsWidgets);
      expect(find.text('I’ll try this'), findsOneWidget);

      for (final completion in <String>['Done', 'Completed', 'Finished']) {
        expect(
          find.textContaining(completion),
          findsNothing,
          reason: 'adoption records an intention; nothing observes the doing',
        );
      }
    });

    testWidgets('NO RAW ID AND NO BRACKET MARKER REACHES ANY SURFACE', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: ActionsScreen(now: now)));
      await tester.pumpAndSettle();

      final printed = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .join('\n');
      expect(
        printed.contains('['),
        isFalse,
        reason: 'a citation marker is rendered as a source, never printed',
      );
      expect(
        RegExp(r'\b[a-z]+_[a-z_]+\b').firstMatch(printed)?.group(0),
        isNull,
        reason: 'a snake_case id is a log line where a source name belongs',
      );
      // The fixture's `signal_source` is `sleep_debt`, which this build has no
      // owner-facing name for. It says so in words rather than printing the id
      // or prettifying it into a phrase nobody chose.
      expect(
        find.text('Raised by a reading with no name in this app'),
        findsOneWidget,
      );
      expect(signalLabel('rhr_daily'), 'Raised by your resting heart rate');
      expect(signalLabel(null), isNull);

      // THE regression, seen on the owner's device: the server sends the metric
      // AND its reading — "recovery_score = 32" — and looking the whole string
      // up in the name table found nothing, so BOTH cards on Actions printed
      // "Raised by a reading this build cannot name yet". A sentence about the
      // build's limitations, shown to somebody who does not have one, about data
      // that was nameable all along.
      // "recovery", not "recovery score" — the app's own name table decides
      // what a metric is called, and this line must not invent a second name
      // for it just because the id is longer.
      expect(
        signalLabel('recovery_score = 32'),
        'Raised by your recovery (32)',
      );
      expect(
        signalLabel('sleep_regularity_index = 62.1'),
        'Raised by your sleep regularity (62.1)',
      );
      // A signal with no reading still names its metric.
      expect(signalLabel('rhr_daily = '), 'Raised by your resting heart rate');
    });
  });

  group('geometry at every phone width', () {
    for (final width in <double>[320, 360, 390, 414]) {
      testWidgets('nothing on Actions runs past the page at $width', (
        tester,
      ) async {
        tester.view
          ..physicalSize = Size(width * 3, 2600)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          todayHost(store, home: ActionsScreen(now: now)),
        );
        await tester.pumpAndSettle();

        for (final finder in <Finder>[
          find.byType(FocusCard),
          find.byType(RowCard),
          find.byType(SuggestionRow),
        ]) {
          for (final element in finder.evaluate()) {
            final rect = tester.getRect(
              find.byElementPredicate((candidate) => candidate == element),
            );
            expect(rect.left, greaterThanOrEqualTo(0), reason: '$width');
            expect(rect.right, lessThanOrEqualTo(width), reason: '$width');
            expect(rect.height, greaterThan(0), reason: '$width');
          }
        }
      });
    }

    testWidgets('THE HEAD’S TITLE IS INTRINSIC, THE AVATAR TAKES THE REST', (
      tester,
    ) async {
      // `Flexible` beside `Expanded` in one Row splits the space 50/50 and
      // ellipsizes the title. The head's title column is `Expanded` and the
      // avatar is not in a flex at all, so the title keeps its own width.
      tester.view
        ..physicalSize = const Size(960, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store, home: ActionsScreen(now: now)));
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text(kActionsTitle));
      expect(title.width, greaterThan(320 * 0.5));
    });
  });
}
