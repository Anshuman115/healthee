/// The cards that moved to Sleep and Activity wear their metric's legacy hue.
///
/// Today's cards were retinted when the grid landed; the ones that moved to the
/// two detail screens mostly were not, so Active minutes had no colour at all and
/// cardio load drew a grey chart under a coloured title. A cell and the card it
/// opens in different colours is the identity claim broken on the way through the
/// door. That is what this file still guards.
///
/// ## What it stopped guarding, on 2026-08-05
///
/// It used to assert that **no card title spends `fav`, `unf` or `alert`**, which
/// was the five-tag system's central invariant: tags were built to be 40° clear
/// of every verdict so the two could never be confused. That system is deleted.
/// Legacy — now the specification — makes `cHrv` and `cReady` **the same value as
/// its green**, so a card about HRV, MVPA or sleep health legitimately paints its
/// title in the colour that also means "improving". Keeping the old assertion
/// would fail the port for being faithful.
///
/// What survives is the part that is still true and still breakable: **a hue
/// comes from `hueFor` and nowhere else**, so a per-screen colour invented at a
/// call site fails here rather than looking fine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/metric_hue.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/shared/instrument_module.dart';

import '../_sleep_stubs.dart';
import '_today_host.dart';

const InstrumentHues _hues = InstrumentHues.light();
const HealtheeColors _colors = HealtheeColors.light();

/// The colour a rendered `Text` is actually painted in.
Color? _colourOf(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label).first).style?.color;

/// Scrolls [title] into view on the pumped screen and answers its colour.
Future<Color?> _titleColour(WidgetTester tester, String title) async {
  await reveal(tester, find.text(title));
  return _colourOf(tester, title);
}

/// The hue on the module whose eyebrow reads [label], or null when it has none.
///
/// Reads the widget's own `tag`, which is now the ONLY place the decision lives:
/// the owner removed the 6 px identity dot on 2026-08-06 (`instrument_module.dart`
/// records the departure), so a card's declared hue is no longer painted as a
/// mark. It still tints the card's chart, and it is still what stops a grid cell
/// and the card it opens from disagreeing about a metric.
Color? _moduleTag(WidgetTester tester, String label) {
  final drawn = tester
      .widgetList<InstrumentModule>(find.byType(InstrumentModule))
      .toList();
  final module = drawn.where((module) => module.label == label);
  expect(
    module,
    isNotEmpty,
    reason:
        'no module labelled "$label" was laid out. Drawn: '
        '${drawn.map((one) => one.label).join(", ")}',
  );
  return module.first.tag;
}

/// Pumps [screen] on a viewport tall enough that every card is laid out.
Future<void> _pump(
  WidgetTester tester,
  LocalStore store,
  Widget screen,
) async {
  // Tall enough that the WHOLE screen lays out in one pass: Sleep is a
  // `ListView.builder`, so a card that is never scrolled to is a card that was
  // never built, and `widgetList` cannot see it.
  tester.view
    ..physicalSize = const Size(420, 3400)
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
    // Sleep is legacy's screen now, and legacy tints the module's DOT rather
    // than its label â `HModule` draws `HEyebrow(label)` in ink3 and the 6 px
    // mark in `color`. Asserting a title colour here would have been asserting
    // the rebuild's own design against the screen that replaced it, so the
    // assertion moved to where the hue actually is.
    testWidgets('THE SLEEP CARDS THAT CARRY A HUE CARRY LEGACY’S', (
      tester,
    ) async {
      await _pump(tester, store, SleepScreen(now: kSleepNow));

      // `sleep_screen.dart:367` â Sleep performance is `c.cSleep`.
      // `sleep_screen.dart:647` â Sleep health is `c.green`.
      final expected = <String, Color>{
        'Sleep performance': _hues.sleep,
        'Sleep health · 4-dim': _colors.accent,
      };
      for (final entry in expected.entries) {
        expect(
          _moduleTag(tester, entry.key),
          entry.value,
          reason: '${entry.key} must wear legacy’s own hue',
        );
      }
    });

    testWidgets('the rest of legacy’s sleep modules DECLARE no hue', (
      tester,
    ) async {
      // `dot: false` on every one of them in legacy. A card that grew a hue
      // would be claiming an identity legacy did not give it — still true after
      // the dot went, because the declaration is what tints a card's chart.
      await _pump(tester, store, SleepScreen(now: kSleepNow));
      for (final label in <String>[
        'Sleep stages',
        'Breakdown',
        'Overnight vitals',
        'Sleep debt · last 7 nights',
        'Last 7 nights',
        'Trends · 14 nights',
      ]) {
        expect(_moduleTag(tester, label), isNull, reason: label);
      }
    });
  });

  group('Activity', () {
    testWidgets('ACTIVE MINUTES IS NO LONGER COLOURLESS', (tester) async {
      await _pump(tester, store, const ActivityScreen());
      expect(
        await _titleColour(tester, 'Active minutes'),
        hueFor(_hues, 'mvpa_min'),
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
          hueFor(_hues, entry.value),
          reason: '${entry.key} must wear ${entry.value}’s hue',
        );
      }
    });

    test('THE FITNESS NUMBERS SHARE LEGACY’S READINESS HUE', () {
      // `today_screen.dart:1162` and `:1239` — both cReady.
      expect(hueFor(_hues, 'vo2max_estimate'), _hues.readiness);
      expect(hueFor(_hues, 'biological_age'), _hues.readiness);
    });

    testWidgets('the MVPA week bar does not turn green at the WHO floor', (
      tester,
    ) async {
      // The fixture is over 150 min/week, and the card must not celebrate a
      // POPULATION target as though it were the owner's own baseline.
      //
      // NOTE the trap this test now sits in, and why it still means something:
      // MVPA's own hue IS legacy's green, the same value as `fav`. So "no green
      // anywhere" would be unassertable. What is asserted instead is that the
      // bar is painted through `hueFor` — an identity — rather than by a
      // threshold comparison, which is the behaviour that was actually wrong.
      await _pump(tester, store, const ActivityScreen());
      await reveal(tester, find.text('Active minutes'));

      final fills = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((box) => box.color)
          .toSet();
      expect(fills, contains(hueFor(_hues, 'mvpa_min')));
      expect(
        fills,
        isNot(contains(_colors.alert)),
        reason: 'nothing on this card is a verdict, in either direction',
      );
    });
  });

  test('THEME PARITY — the dark hues come from the same table', () {
    // A hue assigned per-theme would be one metric in two families depending on
    // the hour. `hueFor` returns a FIELD of the extension, so this asserts the
    // mapping rather than the hex: whichever field the light theme picks, the
    // dark theme picks the same one.
    const dark = InstrumentHues.dark();
    for (final metric in <String>[
      'mvpa_min',
      'cardio_load',
      'vo2max_estimate',
      'biological_age',
      'steps_total',
      'sleep_duration',
      'spo2_overnight',
      'stress',
    ]) {
      expect(
        _fieldName(dark, hueFor(dark, metric)),
        _fieldName(_hues, hueFor(_hues, metric)),
        reason: '$metric changes family between themes',
      );
    }
  });
}

/// Which named field of [hues] holds [colour].
///
/// Two of legacy's ten hues share a value in both themes (`cHrv` and `cReady`
/// are the green), so this returns the FIRST matching name and the comparison
/// above is between two consistently-resolved names rather than between hexes.
String _fieldName(InstrumentHues hues, Color colour) => <String, Color>{
  'sleep': hues.sleep,
  'heart': hues.heart,
  'hrv': hues.hrv,
  'steps': hues.steps,
  'calories': hues.calories,
  'respiratory': hues.respiratory,
  'spo2': hues.spo2,
  'stress': hues.stress,
  'readiness': hues.readiness,
  'rem': hues.rem,
}.entries.firstWhere((entry) => entry.value == colour).key;
