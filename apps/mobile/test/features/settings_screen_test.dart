/// Settings — one source of truth per setting, and no row that controls nothing.
///
/// `reachability_test.dart` covers where each row GOES. This covers the two
/// rules the screen was built to keep:
///
///   * **The appearance row and the header toggle are one state.** They write the
///     same `themeControllerProvider`, so the round button in a screen header
///     moves this row and this row moves the button. A `bool _dark` in either
///     widget's `State` would be a second copy of a fact the app already has, and
///     it would disagree in exactly one direction, once, on somebody's phone.
///   * **Every row says something true about this phone.** The strap row reports
///     `lastCompleteSync`, never `lastAttempt` — an attempt that failed halfway
///     left data unread, and calling it a sync is the stale-behind-a-healthy-
///     screen failure one screen over.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/settings/app_version.dart';
import 'package:healthee/features/settings/settings_screen.dart';
import 'package:healthee/features/settings/widgets/strap_setting.dart';

import '../pairing/_pairing_fakes.dart';

final DateTime _now = DateTime(2026, 8, 5, 9, 30);

const PairedStrap _strap = PairedStrap(
  mac: 'C0:FF:EE:00:00:01',
  authKey: '000102030405060708090a0b0c0d0e0f',
);

/// A day with one complete sync and a battery reading behind it.
DeviceDay _dayWithSync() {
  final empty = DeviceDay.empty('2026-08-05');
  return DeviceDay(
    date: empty.date,
    steps: empty.steps,
    distanceKm: empty.distanceKm,
    deviceCalories: empty.deviceCalories,
    stepsReadAt: null,
    heartRate: empty.heartRate,
    heartRateSeries: empty.heartRateSeries,
    lastNight: empty.lastNight,
    metrics: empty.metrics,
    workouts: empty.workouts,
    sync: DeviceSyncStamp(
      lastCompleteSync: _now.subtract(const Duration(minutes: 12)),
      lastAttempt: _now,
      lastOutcomeId: 'complete',
    ),
    batteryPercent: 71,
  );
}

Widget _settings({
  PairedStrap? strap,
  DeviceDay? day,
  bool signedIn = false,
  ThemeMode? mode,
  String? version,
}) {
  final secrets = FakeSecretStore();
  return ProviderScope(
    overrides: [
      credentialsProvider.overrideWithValue(Credentials(secrets)),
      pairingSummaryProvider.overrideWith(
        (ref) async => (strap: strap, zeppRemembered: false),
      ),
      serverSessionProvider.overrideWith(
        (ref) async => signedIn
            ? const ServerSessionStatus(
                signedIn: true,
                baseUrl: 'https://healthee.example.test',
              )
            : const ServerSessionStatus.signedOut(),
      ),
      deviceDayProvider.overrideWith((ref) async => day ?? DeviceDay.empty('2026-08-05')),
      // The real read talks to a platform channel a test host never answers,
      // and its own deadline would leave a pending timer behind every widget
      // test that draws this row.
      appVersionProvider.overrideWith((ref) async => version),
      if (mode case final ThemeMode pinned)
        themeControllerProvider.overrideWith(() => _FixedTheme(pinned)),
    ],
    child: _ThemedApp(now: _now),
  );
}

/// The settings screen under the app's real theme wiring, so the appearance row
/// can be observed changing the theme rather than merely changing a provider.
class _ThemedApp extends ConsumerWidget {
  const _ThemedApp({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeControllerProvider),
      home: SettingsScreen(now: now),
    );
  }
}

class _FixedTheme extends ThemeController {
  _FixedTheme(this._mode);

  final ThemeMode _mode;

  @override
  ThemeMode build() => _mode;
}

void _tallViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(420, 2400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('appearance is ONE state, not a second toggle', () {
    testWidgets('the row shows the mode the app is actually in', (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_settings(mode: ThemeMode.dark));
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(segmented.selected, <ThemeMode>{ThemeMode.dark});
    });

    testWidgets('CHOOSING A MODE HERE MOVES THE HEADER TOGGLE TOO', (tester) async {
      // The proof that they are one state: the toggle reads the brightness
      // actually being rendered, so the settings row changing the theme is what
      // changes the button's icon. Two copies could not do this.
      _tallViewport(tester);
      await tester.pumpWidget(_settings());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsScreen));
      expect(
        Theme.of(context).brightness,
        Brightness.dark,
        reason: 'the row writes the same provider the header button writes',
      );
    });
  });

  group('the strap row', () {
    testWidgets('reports the last COMPLETE sync and the battery behind it', (
      tester,
    ) async {
      _tallViewport(tester);
      await tester.pumpWidget(_settings(strap: _strap, day: _dayWithSync()));
      await tester.pumpAndSettle();

      expect(find.text('Paired'), findsOneWidget);
      expect(find.text(_strap.mac), findsOneWidget);
      expect(find.textContaining('Last full sync 12 min ago.'), findsOneWidget);
      expect(find.textContaining('Battery 71% at that sync.'), findsOneWidget);
    });

    testWidgets('an unpaired phone says so and offers pairing', (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_settings());
      await tester.pumpAndSettle();

      expect(find.text('No strap paired'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Pair a strap'), findsOneWidget);
    });

    test('a phone with no finished sync does not call that a fault', () {
      // Freshly paired is this state for a minute and nothing is wrong with it.
      final lines = strapLines(DeviceDay.empty('2026-08-05'), now: _now);

      expect(lines.first, 'No sync has finished on this phone yet.');
      expect(lines.last, contains('has not reported its battery'));
    });

    test('a lastAttempt is NEVER reported as a sync', () {
      // The two are different facts: an attempt that failed halfway left data
      // unread. `device_day.dart` keeps both and this row reads only one.
      final attemptedOnly = DeviceDay.empty('2026-08-05');
      expect(attemptedOnly.sync.lastCompleteSync, isNull);
      expect(
        strapLines(attemptedOnly, now: _now).first,
        isNot(contains('Last full sync')),
      );
    });
  });

  group('the server row', () {
    testWidgets('a signed-out phone says the strap still works', (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_settings());
      await tester.pumpAndSettle();

      expect(find.text('Not signed in'), findsOneWidget);
      expect(find.textContaining('still syncs to this phone'), findsOneWidget);
    });

    testWidgets('a signed-in phone shows the address and never a token', (tester) async {
      _tallViewport(tester);
      await tester.pumpWidget(_settings(signedIn: true));
      await tester.pumpAndSettle();

      expect(find.text('Signed in'), findsOneWidget);
      expect(find.text('https://healthee.example.test'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Sign out or change server'),
        findsOneWidget,
        reason: 'the label names what is behind it, rather than "Manage"',
      );
    });
  });

  group('about', () {
    testWidgets('the licence notice is reachable in the shipped app', (tester) async {
      // A licence term, not a nicety: the SIL OFL requires the notice to travel
      // with the fonts, and `assets/fonts/OFL.txt` shipped only to git until it
      // became an asset with a door.
      _tallViewport(tester);
      await tester.pumpWidget(_settings());
      await tester.pumpAndSettle();

      final licences = find.widgetWithText(OutlinedButton, 'Licences and notices');
      await tester.scrollUntilVisible(licences, 300);
      expect(find.textContaining('SIL Open Font License'), findsOneWidget);

      await tester.tap(licences);
      await tester.pumpAndSettle();
      expect(find.textContaining('Healthee'), findsWidgets);
    });

    testWidgets('a host with no plugin says so rather than inventing a version', (
      tester,
    ) async {
      // A host with no plugin registrant answers nothing at all, so the read
      // resolves to null through its own deadline. The row names the build it
      // does not know rather than showing one it made up.
      _tallViewport(tester);
      await tester.pumpWidget(_settings());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('About'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Version unavailable on this device'), findsOneWidget);
      expect(
        find.text('Reading the version…'),
        findsNothing,
        reason: 'a row that waits forever is the failure this app is against',
      );
    });
  });
}
