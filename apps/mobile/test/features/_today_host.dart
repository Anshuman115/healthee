/// The Today host every widget suite in this directory pumps.
///
/// Extracted on its second use (Standards §1). Two suites now render this
/// screen — one about what it draws, one about the connection strip in its
/// chrome — and a second copy of these overrides is a second chance to forget
/// one of them, which shows up as "pumpAndSettle timed out" rather than as
/// anything about the test.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/app.dart';
import 'package:healthee/ble/models/device_daily_totals.dart';
import 'package:healthee/ble/models/strap_sample.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_insight.dart';
import 'package:healthee/data/models/sleep_page.dart';
import 'package:healthee/data/models/today_view.dart';
import 'package:healthee/data/pairing/paired_strap.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/data/today_repository.dart';
import 'package:healthee/features/settings/app_version.dart';
import 'package:healthee/features/today/today_screen.dart';

import '../_sleep_stubs.dart';
import '../_today_stubs.dart';
import '../store/strap_store_test.dart' show nightOn, resultWith;

const String todayDate = '2026-08-04';
final DateTime now = DateTime(2026, 8, 4, 9, 30);

/// The screen over [store], with the day, the clock, the link and the payload
/// all pinned.
///
/// The connection is ALWAYS overridden, even when a test does not care about
/// it. The real controller opens a strap session as soon as anything watches it
/// — which is the point of the feature and exactly wrong inside a widget test,
/// where it would reach for a radio that does not exist. The lifecycle
/// behaviour has its own suite (`test/sync/foreground_lifecycle_test.dart`)
/// against a scripted device.
/// The server session is ALWAYS overridden too, and defaults to signed in. The
/// real provider reaches the platform keystore, which a `flutter test` host does
/// not have — and the data-health strip speaks up when there is no session, so
/// leaving it unpinned would make every "this section falls silent" assertion
/// depend on a plugin channel that is not there.
///
/// [home] is the screen under test and defaults to Today. Sleep, Activity, Coach
/// and Diagnostics read the SAME two providers through the same shell
/// (`shared/instrument_screen.dart`), so one host serves all five rather than
/// four more copies of these overrides.
Widget todayHost(
  LocalStore store, {
  StrapConnection? connection,
  TodayView? server,
  bool serverUnreachable = false,
  ThemeData? themeOverride,
  bool signedIn = true,
  Widget? home,
  SleepPage? sleep,
  SleepConsistency? consistency,
}) {
  return _scoped(
    store,
    connection: connection,
    server: server,
    serverUnreachable: serverUnreachable,
    signedIn: signedIn,
    sleep: sleep,
    consistency: consistency,
    child: MaterialApp(
      theme: themeOverride ?? AppTheme.light,
      home: home ?? TodayScreen(now: now),
    ),
  );
}

/// The whole app on its REAL router, so tab switching is the real thing.
///
/// [todayHost] pumps one screen with no router at all, which is right for asking
/// what a screen draws and useless for asking what a tab switch costs. The
/// pairing summary is pinned to a paired strap because `buildRouter` redirects an
/// unpaired app to `/pairing` — a test of the tab shell would otherwise never see
/// a tab.
Widget routedApp(LocalStore store) =>
    _scoped(store, paired: true, child: const HealtheeApp());

/// The overrides that keep a widget test off the network and off the keystore,
/// wrapped around [child].
///
/// A wrapper rather than a returned override list, for the reason
/// `_today_stubs.dart` already records: `Override` is not exported by
/// `flutter_riverpod`, and reaching past that boundary to save a parameter is not
/// worth it. Extracted on its second use (Standards §1) — a second copy of these
/// is a second chance to forget one, which surfaces as "pumpAndSettle timed out"
/// rather than as anything about the test.
Widget _scoped(
  LocalStore store, {
  required Widget child,
  StrapConnection? connection,
  TodayView? server,
  bool serverUnreachable = false,
  bool signedIn = true,
  bool paired = false,
  SleepPage? sleep,
  SleepConsistency? consistency,
}) {
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      todayProvider.overrideWithValue(todayDate),
      syncControllerProvider.overrideWith(
        () => _FixedConnection(connection ?? const Disconnected()),
      ),
      serverSessionProvider.overrideWith(
        (ref) async => signedIn
            ? const ServerSessionStatus(
                signedIn: true,
                baseUrl: 'https://healthee.example.com',
              )
            : const ServerSessionStatus.signedOut(),
      ),
      todaySnapshotProvider.overrideWith(
        serverUnreachable ? todayUnreachable() : todayIs(server ?? todayView()),
      ),
      // Settings is reachable from Today now, and its About row reads a platform
      // channel a test host never answers — which would leave that read's own
      // deadline pending after any test that navigated there.
      appVersionProvider.overrideWith((ref) async => null),
      // Sleep reads three payloads of its own — `/api/sleep`,
      // `/api/sleep/consistency` and `/api/sleep/insight`. All three are
      // pinned for the same reason the Today one is: an unpinned provider
      // reaches for a socket and fails as "pumpAndSettle timed out", which
      // says nothing about the test. The insight defaults to LOCKED so no
      // suite leaves a spinner running that `pumpAndSettle` will wait on.
      sleepPageProvider.overrideWith(
        (ref) async => serverUnreachable
            ? throw StateError('no server')
            : sleep ?? sleepPageFixture(),
      ),
      sleepConsistencyProvider.overrideWith(
        (ref) async => serverUnreachable
            ? throw StateError('no server')
            : consistency ?? consistencyFixture(),
      ),
      sleepInsightProvider.overrideWith(
        (ref) async => const SleepInsight.locked(),
      ),
      if (paired)
        pairingSummaryProvider.overrideWith(
          (ref) async => (
            strap: const PairedStrap(
              mac: 'C0:FF:EE:00:00:01',
              authKey: '000102030405060708090a0b0c0d0e0f',
            ),
            zeppRemembered: false,
          ),
        ),
    ],
    child: child,
  );
}

/// A controller pinned to one state, so each case can be rendered on its own.
class _FixedConnection extends SyncController {
  _FixedConnection(this._state);

  final StrapConnection _state;

  @override
  StrapConnection build() => _state;
}

/// Seeds one ordinary day of strap measurements.
Future<void> seedDevice(LocalStore store) async {
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
}

/// Scrolls until [finder] is on screen. The list is a `ListView.builder`, so
/// most of Today is not built until it is needed — which is the point of it.
Future<void> reveal(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 400);

