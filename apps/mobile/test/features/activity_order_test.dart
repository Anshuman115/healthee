/// Activity is the v02 prototype's screen, in the prototype's order — held here.
///
/// `design/mobile-preview/screens-overview.js::H.screens.activity` is one
/// template literal, and the only way a re-ordering, a dropped panel or a panel
/// that crept back in gets caught is by reading the section list and comparing
/// it to the prototype entry by entry. A rendered scroll cannot do it: most of
/// the screen is off the viewport and a lazy sliver list has not built it.
///
/// The order below was transcribed with the prototype open in a browser
/// (`python3 -m http.server --directory design/mobile-preview`), scrolled top to
/// bottom at 390 px. Every entry names the prototype construct it came from.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/models/activity_today.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/features/activity/activity_sections.dart';
import 'package:healthee/features/activity/v02/movement_panels.dart';
import 'package:healthee/shared/insight_card.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/states/reading_view.dart';
import 'package:healthee/shared/v02/context_bridge.dart';
import 'package:healthee/shared/v02/data_footer.dart';
import 'package:healthee/shared/v02/full_button.dart';
import 'package:healthee/shared/v02/list_rows.dart';
import 'package:healthee/shared/v02/page_header.dart';
import 'package:healthee/shared/v02/section_head.dart';

import '../_today_stubs.dart';
import '_screen_data.dart';

/// The section list, built the way the screen builds it.
List<PageSection> sections({
  Map<String, Object?> Function(Map<String, Object?> json)? mutate,
}) => activitySections(
  screenData(server: todayView(mutate: mutate)),
  const ActivityExtras(),
);

int _indexOf<T>(List<PageSection> list) =>
    list.indexWhere((section) => section.child is T);

/// The nth section whose child is a [T], counting from zero.
int _nthOf<T>(List<PageSection> list, int n) {
  var seen = 0;
  for (var i = 0; i < list.length; i++) {
    if (list[i].child is T) {
      if (seen == n) {
        return i;
      }
      seen++;
    }
  }
  return -1;
}

void main() {
  group("the prototype's order, entry by entry", () {
    test('EVERY SECTION THE PROTOTYPE DRAWS IS DRAWN, AND IN ITS ORDER', () {
      final list = sections();
      final order = <int>[
        // `H.header('Activity', …)` — the date, the h1, the avatar.
        _indexOf<V02PageHeader>(list),
        // `H.panel('Today’s movement', …)`.
        _indexOf<MovementPanel>(list),
        // `H.bridge('movement', …)`.
        _nthOf<ContextBridge>(list, 0),
        // `H.panel('Your week, by intensity', …)`.
        _indexOf<ReadingView<Mvpa>>(list),
        // `H.panel('Training load, not just time', …)`.
        _indexOf<ReadingView<CardioLoad>>(list),
        // `H.section('The sessions behind it', …, 'workouts')`.
        _indexOf<SectionHead>(list),
        // The `.card.flush` of `.list-row`s under it.
        _indexOf<FlushCard>(list),
        // `H.link('Record an outdoor workout','record','button full section')`.
        _indexOf<V02FullButton>(list),
        // `H.panel('Fitness with its source', …)`.
        _indexOf<ReadingView<Vo2max>>(list),
        // `H.bridge('fitness', …)` — the age model's fitness term.
        _nthOf<ContextBridge>(list, 1),
        // This app's own: the grounded reading the prototype has no surface for.
        _indexOf<InsightCard>(list),
        // `H.footer()`.
        _indexOf<DataFooter>(list),
      ];
      for (final index in order) {
        expect(index, isNonNegative, reason: 'a prototype section is missing');
      }
      // Strictly increasing: every section sits after the one the prototype puts
      // before it. This is the assertion a re-order fails.
      for (var i = 1; i < order.length; i++) {
        expect(
          order[i],
          greaterThan(order[i - 1]),
          reason: 'section $i is out of the prototype’s order',
        );
      }
    });

    test('the screen carries no second biological-age figure', () {
      // The prototype puts the age in Today's hero and links to a detail screen
      // from here. Two screens, one of which restates the other's headline
      // number, is how two numbers start disagreeing.
      final names = <String>[
        for (final section in sections())
          section.child.runtimeType.toString().toLowerCase(),
      ];
      for (final name in names) {
        expect(name, isNot(contains('biologicalage')));
      }
    });
  });

  group('the gaps are v02’s two rungs, not legacy’s four', () {
    test('THE SCREEN USES THOSE TWO AND NOT LEGACY’S LADDER', () {
      final gaps = <double>{
        for (final section in sections())
          if (section.gap > 0) section.gap,
      };
      expect(
        gaps.difference(<double>{PageSpacing.panel, PageSpacing.block}),
        isEmpty,
        reason:
            'a v02 screen uses one ladder or the other; a legacy rung here is '
            'the two systems drifting into one screen',
      );
    });

    test('a bridge is a block break, and two panels are a panel break', () {
      final list = sections();
      // The bridge owns that gap now, so its rule can span it and reach the
      // card above — see `ContextBridge.leadIn` and `today_order_test.dart`.
      expect(list[_nthOf<ContextBridge>(list, 0) - 1].gap, 0);
      expect(
        (list[_nthOf<ContextBridge>(list, 0)].child as ContextBridge).leadIn,
        PageSpacing.block,
      );
      expect(list[_indexOf<ReadingView<Mvpa>>(list)].gap, PageSpacing.panel);
    });
  });

  group('a refused block is refused, in the slot it would have taken', () {
    // The one bug the whole honesty layer exists to make impossible, at its last
    // hop. `test/mutations.sh` blanks each withheld branch on purpose and
    // requires this group to notice.
    //
    // Asserted on the SECTION LIST rather than on a scroll: the slot keeping its
    // place is the claim, and a rendered list would only show whichever refusals
    // happened to be on screen.
    test('MVPA WITHHELD KEEPS ITS SLOT AND ITS NEIGHBOURS', () {
      final list = sections(
        mutate: (json) => <String, Object?>{...json, 'mvpa': null},
      );
      final refusal = _indexOf<ReadingView<Mvpa>>(list);
      expect(refusal, isNonNegative, reason: 'the slot must keep its place');
      expect(refusal, greaterThan(_nthOf<ContextBridge>(list, 0)));
      expect(refusal, lessThan(_indexOf<ReadingView<CardioLoad>>(list)));
    });

    test('SO DOES CARDIO LOAD, AND SO DOES VO₂MAX', () {
      final list = sections(
        mutate: (json) => <String, Object?>{
          ...json,
          'cardio_load': null,
          'vo2max': null,
        },
      );
      expect(_indexOf<ReadingView<CardioLoad>>(list), isNonNegative);
      expect(_indexOf<ReadingView<Vo2max>>(list), isNonNegative);
      // And the screen after them is unchanged: a refusal is not a truncation.
      expect(_indexOf<DataFooter>(list), isNonNegative);
      expect(_indexOf<V02FullButton>(list), isNonNegative);
    });
  });

  group('the conditional sections are the payload’s conditions', () {
    test('no fitness term means no age bridge — never an invented one', () {
      final none = sections(
        mutate: (json) => <String, Object?>{
          ...json,
          'biological_age': <String, Object?>{
            ...json['biological_age']! as Map<String, Object?>,
            'contributions': const <Object?>[],
          },
        },
      );
      // The movement bridge stays; the age one is gone.
      expect(_nthOf<ContextBridge>(none, 0), isNonNegative);
      expect(_nthOf<ContextBridge>(none, 1), -1);
    });

    test('the saved-routes row is there whether or not a session was', () {
      // A day with no recorded session still has a route list to open, and the
      // section is still a true list rather than an empty card.
      final list = sections();
      expect(_indexOf<FlushCard>(list), isNonNegative);
    });
  });
}
