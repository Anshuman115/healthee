/// `.date-navigation` — previous, next, the calendar, and the way back.
///
/// The prototype's header carries a date CONTROL, not a date label, and the
/// selection follows the reader between screens. This suite holds the control's
/// behaviour and the one thing it must never be allowed to cause.
///
/// ## The refusal is the load-bearing half
///
/// `/api/today` takes no day. Every judgement on the screen — recovery, sleep
/// health, debt, VO₂max, biological age — is computed for the current day and
/// only that one. So a date control creates a way to have today's numbers on
/// screen with yesterday's date above them, which is **stale-as-current**: the
/// failure `LastKnown` exists for, the one `vo2max_tier.py`'s freshness horizon
/// exists for, and the one this repo has already swept three times.
///
/// `todaySections` refuses instead. The last group here is that refusal, tested
/// against the section list directly rather than through a scroll, because what
/// is being asserted is what the screen DECIDED — a rendered viewport would pass
/// while the hero sat one scroll below it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/history/dated_history.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/trend_point.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/store/view_date.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/features/today/today_measured.dart';
import 'package:healthee/features/today/today_sections.dart';
import 'package:healthee/features/today/v02/date_calendar_sheet.dart';
import 'package:healthee/features/today/v02/date_control.dart';
import 'package:healthee/features/today/v02/today_hero.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/v02/chapter.dart';
import 'package:healthee/shared/v02/dated_panel.dart';

import '../_today_stubs.dart';
import '_screen_data.dart';
import '_today_host.dart';

/// The window Today hands the control, as `today_screen.dart` builds it.
DateNavigation _window({ValueChanged<String>? onSelect}) => DateNavigation(
  earliest: earliestViewableDay(todayDate),
  latest: todayDate,
  onSelect: onSelect ?? (_) {},
);

/// The section list for a phone showing [day], with a server that only ever
/// answers for [todayDate].
List<PageSection> _sectionsFor(String day, {DatedHistory? history}) =>
    todaySections(
      screenData(
        day: DeviceDay.empty(day),
        server: todayView(),
        history: history,
      ),
      TodayExtras(navigation: _window()),
    );

/// A fortnight of resting heart rate that runs PAST the day under test, so a
/// panel that windowed on the newest reading rather than on the selection would
/// have somewhere wrong to go.
const DatedHistory _spanning = DatedHistory(
  days: 90,
  series: <String, List<TrendPoint>>{
    'rhr_daily': <TrendPoint>[
      TrendPoint(date: '2026-07-30', value: 50),
      TrendPoint(date: '2026-07-31', value: 51),
      TrendPoint(date: '2026-08-01', value: 52),
      // Everything below is AFTER the day under test.
      TrendPoint(date: '2026-08-02', value: 61),
      TrendPoint(date: '2026-08-03', value: 62),
      TrendPoint(date: '2026-08-04', value: 63),
    ],
  },
);

bool _has<T>(List<PageSection> list) =>
    list.any((section) => section.child is T);

void main() {
  group('the control moves the day', () {
    late LocalStore store;

    setUp(() async {
      store = LocalStore.memory();
      await seedDevice(store);
    });

    tearDown(() => store.close());

    testWidgets('PREVIOUS AND NEXT MOVE IT, AND Latest COMES BACK', (
      tester,
    ) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      // The seeded day. `todayDate` is a Tuesday.
      expect(find.text(prettyDate(todayDate)), findsOneWidget);
      expect(
        find.text(DateControl.latestLabel),
        findsNothing,
        reason: 'there is nowhere to come back from yet',
      );

      await tester.tap(find.byKey(DateControl.previousKey));
      await tester.pumpAndSettle();
      expect(find.text(prettyDate('2026-08-03')), findsOneWidget);
      expect(find.text(prettyDate(todayDate)), findsNothing);

      await tester.tap(find.byKey(DateControl.previousKey));
      await tester.pumpAndSettle();
      expect(find.text(prettyDate('2026-08-02')), findsOneWidget);

      await tester.tap(find.byKey(DateControl.nextKey));
      await tester.pumpAndSettle();
      expect(find.text(prettyDate('2026-08-03')), findsOneWidget);

      await tester.tap(find.byKey(DateControl.latestKey));
      await tester.pumpAndSettle();
      expect(find.text(prettyDate(todayDate)), findsOneWidget);
    });

    testWidgets('it cannot walk past the wall clock', (tester) async {
      // There are no measurements from tomorrow. A control that could ask for
      // one would be offering a screen of withholds and calling it a day.
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DateControl.nextKey));
      await tester.pumpAndSettle();

      expect(find.text(prettyDate(todayDate)), findsOneWidget);
    });

    testWidgets('TAPPING THE DATE OPENS THE CALENDAR', (tester) async {
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DateControl.triggerKey));
      await tester.pumpAndSettle();

      expect(find.text(kDateCalendarTitle), findsOneWidget);
      expect(find.text('August 2026'), findsOneWidget);
      // The dot's claim, said in words rather than left to be guessed at.
      expect(find.text(helpLine), findsOneWidget);

      // A day inside the window is a live control and choosing it moves the
      // screen; the sheet closes behind it.
      await tester.tap(find.byKey(const ValueKey<String>('calendar.2026-08-01')));
      await tester.pumpAndSettle();

      expect(find.text(kDateCalendarTitle), findsNothing);
      expect(find.text(prettyDate('2026-08-01')), findsOneWidget);
    });
  });

  group('a past day is not today with an older label', () {
    test('THE DERIVED HALF IS NOT DRAWN AT ALL', () {
      // Every one of these reads the server's snapshot, which is dated today.
      // Drawing any of them under a past date is the whole failure.
      final past = _sectionsFor('2026-08-01');
      expect(
        _has<ReadingView<BiologicalAge>>(past),
        isFalse,
        reason: 'the biological age',
      );
      expect(_has<TodaySummaryTiles>(past), isFalse, reason: 'the tiles');
    });

    test('AND THE CHAPTERS IT DOES DRAW ARE THE DATED ONES, NOT TODAY’S', () {
      // A past day gained `history-screens.js`'s three chapters of dated
      // measurements. This asserts they are those and not the current day's,
      // which is the whole distinction: `Last night → today` heads a run of
      // judgements about tonight's readiness, `Overnight readings` heads a run
      // of measurements laid on the calendar. Same widget, opposite claims — so
      // the test names them rather than counting them.
      final headings = <String>[
        for (final section in _sectionsFor('2026-08-01'))
          if (section.child case final ChapterHeading heading) heading.title,
      ];
      expect(headings, <String>[
        'Overnight readings',
        'Movement & effort',
        'Fitness & context',
      ]);
      expect(
        _sectionsFor(todayDate).map((s) => s.child).whereType<ChapterHeading>()
            .map((h) => h.title),
        containsAll(<String>['Last night → today', 'Movement → recovery']),
        reason: 'the current day keeps its own three, unchanged',
      );
    });

    test('A PAST DAY DRAWS MEASUREMENTS, AND ONLY MEASUREMENTS', () {
      // The line this whole feature is built against. Everything a dated panel
      // can draw is a row `derive` stamped with a calendar day; everything the
      // refusal covers is worked out for the current day and no other.
      final past = _sectionsFor('2026-08-01');
      expect(_has<DatedPanel>(past), isTrue, reason: 'the dated charts');
      for (final section in past) {
        expect(
          section.child,
          isNot(isA<ReadingView<BiologicalAge>>()),
          reason: 'a derived value reached a past day',
        );
      }
      // And every panel is windowed on the day being READ, never on today.
      for (final section in past) {
        if (section.child case final DatedPanel panel) {
          expect(panel.day, '2026-08-01');
        }
      }
    });

    test('A DATED CHART ENDS ON THE CHOSEN DAY, NOT ON THE NEWEST READING', () {
      // The stale-as-current failure with a chart instead of a figure: the
      // series runs to 4 August and the header says 1 August, so a window taken
      // from the newest reading would put three days of the future on screen
      // under an older date — and the panel's own figure would be one of them.
      final panel = _sectionsFor('2026-08-01', history: _spanning)
          .map((section) => section.child)
          .whereType<DatedPanel>()
          .firstWhere((panel) => panel.metric == 'rhr_daily');
      expect(panel.window.days.last, '2026-08-01');
      expect(panel.window.on('2026-08-01'), 52);
      for (final point in panel.window.observed) {
        expect(
          point.date.compareTo('2026-08-01') <= 0,
          isTrue,
          reason: '${point.date} is after the day being read',
        );
      }
      // 61, 62 and 63 are the readings from after the selection.
      expect(panel.window.values, isNot(contains(61.0)));
    });

    test('and the current day still draws all of it', () {
      // The control has to be free, not a trade. Nothing on the live path moves.
      final today = _sectionsFor(todayDate);
      expect(_has<ReadingView<BiologicalAge>>(today), isTrue);
      expect(_has<ChapterHeading>(today), isTrue);
      expect(_has<TodaySummaryTiles>(today), isTrue);
    });

    test('it says why, rather than leaving a short screen to be read', () {
      // A screen that simply ends is read as a bad day. This one is about US.
      expect(kPastDayNote, contains('current day only'));
      expect(
        _sectionsFor('2026-08-01').length,
        greaterThan(2),
        reason: 'the measured half and its note are still there',
      );
    });

    testWidgets('the header reads the day being shown, not the payload’s', (
      tester,
    ) async {
      final store = LocalStore.memory();
      addTearDown(store.close);
      await seedDevice(store);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DateControl.previousKey));
      await tester.pumpAndSettle();

      expect(find.text(prettyDate('2026-08-03')), findsOneWidget);
      expect(
        find.text('34.3'),
        findsNothing,
        reason: "today's biological age is on screen under yesterday's date",
      );
    });
  });

  group('the window', () {
    test('reaches exactly as far back as the phone keeps a day', () {
      // `horizon_prune.dart` removes a day at 60. A control that offered day 61
      // would be offering history the store has already deleted.
      expect(earliestViewableDay('2026-08-04'), '2026-06-05');
      expect(isViewableDay('2026-06-05', '2026-08-04'), isTrue);
      expect(isViewableDay('2026-06-04', '2026-08-04'), isFalse);
      expect(isViewableDay('2026-08-05', '2026-08-04'), isFalse);
    });

    test('day arithmetic crosses a month and a year end', () {
      expect(shiftDay('2026-03-01', -1), '2026-02-28');
      expect(shiftDay('2026-12-31', 1), '2027-01-01');
    });

    test('AND THE SELECTION ITSELF REFUSES A DAY OUTSIDE IT', () {
      // The bound belongs on the selection, not only on the two chevrons. The
      // calendar can name any day of its month and a future caller has no
      // reason to check first, so the provider is where "this phone cannot
      // speak about that day" has to hold.
      //
      // It refuses rather than clamps: answering a request for one day with a
      // different day would put something nobody asked for on screen under a
      // date they did not choose.
      final container = ProviderContainer(
        // Untyped on purpose: `Override` is not exported by `flutter_riverpod`,
        // which `_today_stubs.dart` already records.
        overrides: [todayProvider.overrideWithValue(todayDate)],
      );
      addTearDown(container.dispose);
      final selection = container.read(viewDateProvider.notifier);

      expect(container.read(viewDateProvider), todayDate);

      selection.select('2026-08-05');
      expect(container.read(viewDateProvider), todayDate, reason: 'tomorrow');

      selection.select('2026-06-04');
      expect(
        container.read(viewDateProvider),
        todayDate,
        reason: 'a day the horizon has already pruned',
      );

      selection.select('2026-08-01');
      expect(container.read(viewDateProvider), '2026-08-01');

      selection.move(-1);
      expect(container.read(viewDateProvider), '2026-07-31');

      selection.latest();
      expect(container.read(viewDateProvider), todayDate);
    });
  });
}
