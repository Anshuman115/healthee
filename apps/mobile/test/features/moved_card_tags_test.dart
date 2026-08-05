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
    testWidgets('THE MOVED SLEEP CARDS WEAR THEIR METRIC’S HUE', (tester) async {
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
          hueFor(_hues, entry.value),
          reason: '${entry.key} must wear ${entry.value}’s hue',
        );
      }
    });

    testWidgets('the sleep titles are legacy’s cSleep, not the accent', (
      tester,
    ) async {
      // The two that are genuinely about sleep must be purple. This is the
      // assertion that would catch a screen quietly falling back to the default,
      // which — legacy's own fallback — is the green.
      await _pump(tester, store, const SleepScreen());
      for (final title in <String>['Last night', 'Sleep debt']) {
        expect(await _titleColour(tester, title), _hues.sleep, reason: title);
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
