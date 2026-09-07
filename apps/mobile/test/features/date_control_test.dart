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
import 'package:healthee/data/models/biological_age.dart';
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
List<PageSection> _sectionsFor(String day) => todaySections(
  screenData(day: DeviceDay.empty(day), server: todayView()),
  TodayExtras(navigation: _window()),
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
      expect(_has<ChapterHeading>(past), isFalse, reason: 'the chapters');
      expect(_has<TodaySummaryTiles>(past), isFalse, reason: 'the tiles');
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
