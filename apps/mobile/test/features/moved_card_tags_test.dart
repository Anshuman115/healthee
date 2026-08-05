/// The cards that moved to Sleep and Activity wear their metric's tag.
///
/// Today's cards were retinted when the grid landed; the ones that moved to the
/// two detail screens mostly were not, so Active minutes had no colour at all and
/// cardio load drew a grey chart under a coloured title. A cell and the card it
/// opens in different colours is the identity claim broken on the way through the
/// door.
///
/// Two rules are checked alongside, because the fix is the kind that can quietly
/// break them:
///
///   * **A tag comes from `tagFor` and nowhere else.** Every assertion below
///     resolves its expected colour through the same table the widget asks, so a
///     per-screen colour invented at a call site fails here rather than looking
///     fine.
///   * **`fav` / `unf` stay reserved.** The MVPA week bar used to turn `fav` at
///     the WHO 150-minute floor, which is a verdict against a POPULATION target
///     and the congratulation that card's own docstring says it does not do.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/metric_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';

import '_today_host.dart';

const MetricHues _hues = MetricHues.light();
const HealtheeColors _colors = HealtheeColors.light();

/// The colour a rendered `Text` is actually painted in.
Color? _colourOf(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label).first).style?.color;

/// Scrolls [title] into view on the pumped screen and answers its colour.
Future<Color?> _titleColour(WidgetTester tester, String title) async {
  await reveal(tester, find.text(title));
  return _colourOf(tester, title);
}

/// Pumps [screen] on a viewport tall enough that every card is laid out.
Future<void> _pump(
  WidgetTester tester,
  LocalStore store,
  Widget screen,
) async {
  tester.view
    ..physicalSize = const Size(420, 1400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(todayHost(store, home: screen));
  await tester.pumpAndSettle();
}

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('Sleep', () {
    testWidgets('THE MOVED SLEEP CARDS WEAR THEIR METRIC’S TAG', (tester) async {
      await _pump(tester, store, const SleepScreen());
      const cases = <String, String>{
        'Last night': 'sleep_duration',
        'Sleep health': 'sleep_health_score_4dim',
        'Sleep debt': 'sleep_debt_min',
        'Your last 7 nights': 'sleep_duration',
        'Blood oxygen overnight': 'spo2_overnight',
      };
      for (final entry in cases.entries) {
        expect(
          await _titleColour(tester, entry.key),
          _hues.tagFor(entry.value),
          reason: '${entry.key} must wear ${entry.value}’s family',
        );
      }
    });

    testWidgets('and none of them spends a verdict colour on it', (tester) async {
      // The debt CHART still draws each night `fav` or `unf` against the owner's
      // own need — that is exactly the claim those two colours are reserved for,
      // and a tag there would erase what it says. The title is a different
      // thing, and must not borrow them.
      await _pump(tester, store, const SleepScreen());
      for (final title in <String>['Last night', 'Sleep debt', 'Sleep health']) {
        final colour = await _titleColour(tester, title);
        expect(colour, isNot(_colors.fav), reason: title);
        expect(colour, isNot(_colors.unf), reason: title);
        expect(colour, isNot(_colors.alert), reason: title);
      }
    });
  });

  group('Activity', () {
    testWidgets('ACTIVE MINUTES IS NO LONGER COLOURLESS', (tester) async {
      await _pump(tester, store, const ActivityScreen());
      expect(
        await _titleColour(tester, 'Active minutes'),
        _hues.tagFor('mvpa_min'),
      );
    });

    testWidgets('steps, cardio load, VO₂max and biological age all carry theirs', (
      tester,
    ) async {
      await _pump(tester, store, const ActivityScreen());
      const cases = <String, String>{
        'Steps': 'steps_total',
        'Cardio load': 'cardio_load',
        'VO₂max': 'vo2max_estimate',
        'Biological age': 'biological_age',
      };
      for (final entry in cases.entries) {
        expect(
          await _titleColour(tester, entry.key),
          _hues.tagFor(entry.value),
          reason: '${entry.key} must wear ${entry.value}’s family',
        );
      }
    });

    test('THE FITNESS NUMBERS SHARE THE MOVEMENT FAMILY', () {
      // They defaulted to `rest`, which put the Fitness section in the sleep
      // colour directly under cardio load in the movement one — three cards
      // about one subject in two families.
      expect(_hues.tagFor('vo2max_estimate'), _hues.move);
      expect(_hues.tagFor('biological_age'), _hues.move);
    });

    testWidgets('NO CARD ON THESE SCREENS SPENDS FAV OR UNF ON A TAG', (
      tester,
    ) async {
      await _pump(tester, store, const ActivityScreen());
      for (final title in <String>[
        'Steps',
        'Cardio load',
        'Active minutes',
      ]) {
        final colour = await _titleColour(tester, title);
        expect(colour, isNot(_colors.fav), reason: title);
        expect(colour, isNot(_colors.unf), reason: title);
        expect(colour, isNot(_colors.alert), reason: title);
      }
    });

    testWidgets('the MVPA week bar does not turn green at the WHO floor', (
      tester,
    ) async {
      // The fixture is over 150 min/week, so the old code drew this `fav`.
      await _pump(tester, store, const ActivityScreen());
      await reveal(tester, find.text('Active minutes'));

      final fills = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((box) => box.color)
          .toSet();
      expect(
        fills,
        isNot(contains(_colors.fav)),
        reason:
            'clearing a population recommendation is not "better than your own '
            'normal", and green here is the congratulation this card refuses',
      );
      expect(fills, contains(_hues.tagFor('mvpa_min')));
    });
  });

  test('THEME PARITY — the dark tags come from the same table', () {
    // A tag assigned per-theme would be one metric in two families depending on
    // the hour. `tagFor` is on the extension, so both themes answer the same
    // FIELD; this asserts the mapping, not the hex.
    const dark = MetricHues.dark();
    for (final metric in <String>[
      'mvpa_min',
      'cardio_load',
      'vo2max_estimate',
      'biological_age',
      'steps_total',
      'sleep_duration',
    ]) {
      expect(
        dark.tagFor(metric) == dark.move,
        _hues.tagFor(metric) == _hues.move,
        reason: '$metric changes family between themes',
      );
    }
  });
}
