/// Today, rendered from real stored strap rows — and refusing where it must.
///
/// The store is a genuine in-memory SQLite database seeded through the same
/// writer a sync uses, so these tests exercise the whole read path rather than a
/// hand-built model. `now` is injected, because a suite that reads the wall
/// clock fails once a day at midnight and passes on the retry.
///
/// The test that matters most is `A WITHHELD VALUE IS NEVER A BARE NUMBER`. A
/// screen that renders a number where the data layer sent a refusal is the one
/// bug this whole architecture exists to make impossible, and it is the last hop
/// — the compiler can force the switch, but only a test can prove the branch
/// draws the hole.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/data/sync/sync_failure.dart';
import 'package:healthee/features/today/today_screen.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/states/value_hole.dart';

import '../store/strap_store_test.dart' show nightOn, resultWith;

const String _today = '2026-08-04';
final DateTime _now = DateTime(2026, 8, 4, 9, 30);

/// The screen over [store], with the day, the clock and the link state pinned.
///
/// The connection is ALWAYS overridden, even when a test does not care about
/// it. The real controller opens a strap session as soon as anything watches it
/// — which is the point of the feature and exactly wrong inside a widget test,
/// where it would reach for a radio that does not exist. The lifecycle
/// behaviour has its own suite (`test/sync/foreground_lifecycle_test.dart`)
/// against a scripted device.
Widget _host(LocalStore store, {StrapConnection? connection}) {
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      todayProvider.overrideWithValue(_today),
      syncControllerProvider.overrideWith(
        () => _FixedConnection(connection ?? const Disconnected()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: TodayScreen(now: _now),
    ),
  );
}

/// A controller pinned to one state, so each case can be rendered on its own.
class _FixedConnection extends SyncController {
  _FixedConnection(this._state);

  final StrapConnection _state;

  @override
  StrapConnection build() => _state;
}

void main() {
  late LocalStore store;

  setUp(() => store = LocalStore.memory());
  tearDown(() async => store.close());

  group('measurements the strap made', () {
    setUp(() async {
      await store.strapWriter.saveSync(
        resultWith(
          totals: DeviceDailyTotals(
            steps: 9264,
            distanceM: 6710,
            calories: 412,
            readAt: DateTime(2026, 8, 4, 9, 12),
          ),
          samples: [
            StrapSample(DateTime(2026, 8, 4, 7), 'hr', 61),
            StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68),
            StrapSample(DateTime(2026, 8, 4, 8), 'hrv', 47),
          ],
          sleep: [nightOn(DateTime(2026, 8, 3, 23, 40))],
          battery: 71,
        ),
      );
      await store.strapWriter.stampAttempt(
        at: DateTime(2026, 8, 4, 9, 12),
        outcomeId: 'complete',
        complete: true,
      );
    });

    testWidgets('the daily counter is on screen, and says which number it is', (
      tester,
    ) async {
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('9,264'), findsOneWidget);
      // The provenance is part of the number: which device, and when.
      expect(find.textContaining('Measured by your strap'), findsWidgets);
      expect(find.textContaining('09:12'), findsWidgets);
      // And which of the strap's TWO step numbers this is (#121).
      expect(find.textContaining('since-midnight counter'), findsOneWidget);
    });

    testWidgets("the strap's calories are labelled as the strap's", (tester) async {
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("412 kcal by the strap's own count"),
        findsOneWidget,
        reason: "the product's energy model is the server's, not this number",
      );
    });

    testWidgets('last night shows measured minutes, not a Healthee score', (
      tester,
    ) async {
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      // ListView.builder builds lazily — the sleep card is below the fold on a
      // test-sized viewport, and that laziness is the point of using it.
      await tester.scrollUntilVisible(find.text('Last night'), 300);

      expect(find.text('6h 20m'), findsOneWidget);
      expect(
        find.textContaining("86/100 by the strap's own score"),
        findsOneWidget,
        reason: 'the device score is shown, and attributed in the same breath',
      );
    });
  });

  group('refusals', () {
    testWidgets('A WITHHELD VALUE IS NEVER A BARE NUMBER', (tester) async {
      // Nothing but heart rate, so steps has no counter behind it.
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68)]),
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      final steps = find.ancestor(
        of: find.text('Steps'),
        matching: find.byType(StateCard),
      );
      expect(steps, findsOneWidget);
      // The card keeps its footprint and its title, and the value slot carries
      // the reason: a number-shaped hole, the word, and the remedy.
      expect(
        find.descendant(of: steps, matching: find.byType(ValueHole)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: steps, matching: find.text('WITHHELD')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: steps,
          matching: find.textContaining('The strap recorded no steps'),
        ),
        findsOneWidget,
      );
      // And nothing anywhere on the card that could be read as a step count.
      expect(
        find.descendant(of: steps, matching: find.text('0')),
        findsNothing,
        reason: '"the strap did not say" must never render as zero',
      );
    });

    testWidgets('a server-derived judgement refuses with its own reason', (
      tester,
    ) async {
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68)]),
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      // The section sits below the measurements, so scroll to it.
      await tester.scrollUntilVisible(find.text('Derived on the server'), 300);

      expect(find.text('Derived on the server'), findsOneWidget);
      expect(
        find.textContaining('one number computed two ways is two numbers'),
        findsWidgets,
      );
    });

    testWidgets('the two refusals do not use each others words', (tester) async {
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68)]),
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      // A stream the sensor did not write says "wear it"; a server number says
      // "the maths lives elsewhere". Collapsing them would send both owners to
      // the wrong place.
      expect(find.textContaining('The strap recorded no'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Derived on the server'), 300);
      expect(find.textContaining('will not work it out on the phone'), findsWidgets);
    });

    testWidgets('a metric with no samples keeps its row and shows a hole', (
      tester,
    ) async {
      await store.strapWriter.saveSync(
        resultWith(samples: [StrapSample(DateTime(2026, 8, 4, 9), 'hr', 68)]),
      );
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('From the strap'), 300);

      expect(find.text('Blood oxygen'), findsOneWidget);
      expect(find.byType(ValueHole), findsWidgets);
    });
  });

  group('a phone that has never synced', () {
    testWidgets('says so once, rather than nine times', (tester) async {
      await tester.pumpWidget(_host(store));
      await tester.pumpAndSettle();

      expect(find.text('Nothing from your strap yet'), findsOneWidget);
      expect(find.textContaining('nothing is estimated'), findsOneWidget);
      expect(
        find.textContaining('never — nothing has been pulled'),
        findsOneWidget,
      );
    });
  });

  group('the connection strip', () {
    for (final (name, state, expected) in <(String, StrapConnection, String)>[
      ('never synced', const Disconnected(), 'Never synced — tap Sync now'),
      (
        'released after a healthy sync',
        Disconnected(lastCompleteSync: _now.subtract(const Duration(minutes: 4))),
        'Synced 4 min ago',
      ),
      ('scanning', const Scanning(), 'Looking for your strap'),
      ('connecting', const Connecting(), 'Connecting'),
      ('authenticating', const Authenticating(), 'Authenticating'),
      ('syncing', const Syncing(), 'Syncing'),
      ('connected', Connected(since: _now), 'Connected'),
    ]) {
      testWidgets('$name renders its own sentence', (tester) async {
        await tester.pumpWidget(_host(store, connection: state));
        await tester.pump();

        expect(find.text(expected), findsOneWidget);
      });
    }

    testWidgets('AN IDLE LINK IS NEVER REPORTED AS A FAULT', (tester) async {
      await tester.pumpWidget(
        _host(
          store,
          connection: Disconnected(
            lastCompleteSync: _now.subtract(const Duration(minutes: 4)),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Not connected'),
        findsNothing,
        reason: 'the app let the link go on purpose; nothing is wrong',
      );
    });

    testWidgets('a failure shows the headline, the age AND the remedy', (
      tester,
    ) async {
      const failure = SyncFailure(
        headline: 'Bluetooth is off',
        remedy: 'Turn Bluetooth on and try again.',
        code: 'bluetooth_off',
        source: 'test',
      );
      await tester.pumpWidget(
        _host(
          store,
          connection: ConnectionFailed(
            failure,
            lastCompleteSync: _now.subtract(const Duration(hours: 9)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bluetooth is off'), findsOneWidget);
      expect(find.text('Last full sync 9 h ago.'), findsOneWidget);
      expect(find.text('Turn Bluetooth on and try again.'), findsOneWidget);
    });

    testWidgets('a busy state offers Stop, never a second Sync now', (
      tester,
    ) async {
      // The strap accepts one connection at a time, so a second "sync now"
      // during a handshake would fail on the radio and report a confusing
      // "couldn't connect" for a strap that is right there, talking to us.
      await tester.pumpWidget(_host(store, connection: const Authenticating()));
      await tester.pump();

      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
    });

    testWidgets('an idle state offers Sync now', (tester) async {
      await tester.pumpWidget(_host(store, connection: const Disconnected()));
      await tester.pump();

      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
    });
  });
}
