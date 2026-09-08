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
import 'package:healthee/features/actions/v02/working_on.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/format/other_day.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/choices.dart';
import 'package:healthee/shared/v02/journal_strip.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/screen_head.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/surfaces.dart';

import '../_today_stubs.dart';
import '_screen_data.dart';
import '_today_host.dart';

/// A one-word name for each section, so the order reads as the prototype's.
String _id(PageSection section) => switch (section.child) {
  ScreenHead() => 'head',
  SuggestionCard() => 'suggestion',
  EmptyState() => 'nothing-suggested',
  LoadingState() => 'pending',
  SectionHead(:final title) => 'section:$title',
  WorkingOn() => 'working-on',
  JournalStrip() => 'journal-strip',
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
      expect(ids.indexOf('note'), 1, reason: 'the caption qualifies the whole set');
      expect(ids.indexOf('note'), lessThan(ids.indexOf('suggestion')));

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
      expect(ids[1], 'nothing-suggested');
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
        'suggestion',
        'section:$kWorkingOnHeading',
        'working-on',
        'section:$kCheckInHeading',
        'journal-strip',
        'section:$kLookBackHeading',
        'rows',
        'footer',
      ]);
    });

    test('a quiet day says so and still offers everything after it', () {
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

      expect(ids.contains('suggestion'), isFalse);
      expect(ids[1], 'nothing-suggested');
      // The rest of the screen is unchanged: an absent suggestion is not an
      // absent screen.
      expect(ids.last, 'footer');
      expect(ids.contains('working-on'), isTrue);
    });

    test('a ranked set repeats the card and relabels only the eyebrow', () {
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
      final cards = sections
          .map((section) => section.child)
          .whereType<SuggestionCard>()
          .toList();
      expect(cards.length, 2);
      expect(cards.first.first, isTrue);
      expect(cards.last.first, isFalse);
    });
  });

  group('the suggestion card', () {
    testWidgets(
      'ITS GROUND IS THE CATEGORY’S FAMILY, NOT A COLOUR IT WAS GIVEN',
      (tester) async {
        await tester.pumpWidget(
          todayHost(store, home: ActionsScreen(now: now)),
        );
        await tester.pumpAndSettle();

        const hues = InstrumentHues.light();
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(FocusCard),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        // The fixture's one recommendation is `category: sleep`.
        expect(decoration.color, Tone.sleep.familySoft(hues));
        expect(
          decoration.color,
          isNot(Tone.fitness.familySoft(hues)),
          reason: 'a card that ignored the category would be the root default',
        );
      },
    );

    testWidgets('THE CHECKBOX IS 24 × 24 AND SAYS INTENTION, NOT COMPLETION', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store, home: ActionsScreen(now: now)));
      await tester.pumpAndSettle();

      expect(find.byType(CheckAction), findsOneWidget);
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(CheckAction),
              matching: find.byType(Container),
            )
            .first,
      );
      // The literal, not the constant: an assertion that reads the number it
      // is checking passes against any value the constant is given.
      expect(box.width, 24);
      expect(box.height, 24);
      expect(CheckAction.boxSize, 24, reason: '.checkbox { width: 24px }');

      expect(find.text(kAdoptLabel), findsOneWidget);
      expect(find.text(kAdoptNote), findsOneWidget);
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
        find.text('Raised by a reading this build cannot name yet'),
        findsOneWidget,
      );
      expect(signalLabel('rhr_daily'), 'Raised by your resting heart rate');
      expect(signalLabel(null), isNull);
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
          find.byType(JournalStrip),
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
