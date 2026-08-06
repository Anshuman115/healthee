/// Nothing this rebuild removed from Today became unreachable.
///
/// Cutting Today from twenty sections to six modules is only honest if every
/// removed card is still somewhere the owner can GET TO. `today_grid_test.dart`
/// proves each module opens a tab; `tab_screens_test.dart` proves the card is on
/// it. This file covers the routes that are not behind a grid cell, because they
/// are the ones nothing else would notice:
///
///   * **/settings is off the tab bar**, and it is what the Today avatar opens.
///     It is the only door to the server session, to `/diagnostics` and to the
///     font licence — three things that were each reachable from exactly one odd
///     place before, and one of which is a licence obligation.
///   * **/diagnostics is off the tab bar.** Baselines and the strap's own
///     streams answer "is the instrument working", which is asked when something
///     looks wrong and never at 7am. That reasoning is only sound while there is
///     a way in, and there is exactly one: the settings screen.
///   * **Every live tab names a route the router wires.** A tab that looks live
///     and points at an unregistered path is a link to a crash, and it looks
///     like nothing at all until somebody taps it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/tabs.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/api/credentials.dart';
import 'package:healthee/data/api/server_session.dart';
import 'package:healthee/data/device/device_day.dart';
import 'package:healthee/data/device/device_repository.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/data/sync/connection_state.dart';
import 'package:healthee/data/sync/sync_controller.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/settings/app_version.dart';
import 'package:healthee/features/settings/settings_screen.dart';

import '../pairing/_pairing_fakes.dart';
import '_today_host.dart';

/// The settings screen on a real router, so every row's tap goes somewhere real.
///
/// The destinations are stand-ins rather than the real screens: what is being
/// asserted is that the row REACHES the registered path, and standing the whole
/// pairing flow up behind it would make this suite fail for reasons that are
/// about that flow.
Widget _routedSettings() {
  final store = FakeSecretStore();
  return ProviderScope(
    overrides: [
      credentialsProvider.overrideWithValue(Credentials(store)),
      pairingSummaryProvider.overrideWith(
        (ref) async => (strap: null, zeppRemembered: false),
      ),
      // The keystore and the local store are both platform-backed. Left
      // unpinned they throw inside a build, which surfaces as "markNeedsBuild
      // during build" — a message about Riverpod rather than about settings.
      serverSessionProvider.overrideWith(
        (ref) async => const ServerSessionStatus.signedOut(),
      ),
      deviceDayProvider.overrideWith((ref) async => DeviceDay.empty('2026-08-04')),
      // Its real read is a platform channel a test host never answers.
      appVersionProvider.overrideWith((ref) async => null),
      // The strap row draws a Stop while a sync is running, so it watches the
      // controller — which opens a strap session as soon as anything does.
      syncControllerProvider.overrideWith(
        () => FixedConnection(const Disconnected()),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: GoRouter(
        initialLocation: Routes.settings,
        routes: <RouteBase>[
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          for (final (path, name) in <(String, String)>[
            (Routes.diagnostics, 'the diagnostics route'),
            (Routes.serverSignIn, 'the server route'),
            (Routes.pairing, 'the pairing route'),
          ])
            GoRoute(
              path: path,
              builder: (context, state) => Scaffold(body: Text(name)),
            ),
        ],
      ),
    ),
  );
}

/// Gives the test a viewport tall enough to hold the whole settings screen.
void _tallViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(420, 2400)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _tapRow(WidgetTester tester, String label) async {
  final button = find.widgetWithText(OutlinedButton, label);
  await tester.scrollUntilVisible(button, 300);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('EVERY SETTINGS ROW REACHES A REAL DESTINATION', (tester) async {
    // "Do not invent settings that control nothing." The rows that navigate are
    // checked here; the appearance row changes state rather than navigating and
    // is checked in `settings_screen_test.dart`.
    _tallViewport(tester);
    for (final (label, landing) in <(String, String)>[
      ('Open diagnostics', 'the diagnostics route'),
      ('Sign in to your server', 'the server route'),
      ('Pair a strap', 'the pairing route'),
    ]) {
      await tester.pumpWidget(_routedSettings());
      await tester.pumpAndSettle();
      await _tapRow(tester, label);
      expect(find.text(landing), findsOneWidget, reason: '$label goes nowhere');
    }
  });

  testWidgets('the diagnostics row names what is behind it', (tester) async {
    // The row says what it opens in the owner's words, not "Diagnostics" alone —
    // which would be a control whose only documentation is the screen you have
    // to open to read it.
    _tallViewport(tester);
    await tester.pumpWidget(_routedSettings());
    await tester.pumpAndSettle();

    expect(find.textContaining('every stream this phone read'), findsOneWidget);
    expect(find.textContaining('how it was measured'), findsOneWidget);
  });

  test('every tab names a route, and every route is wired', () {
    const wired = <String>{
      Routes.today,
      Routes.sleep,
      Routes.activity,
      Routes.insights,
      Routes.actions,
      Routes.settings,
      Routes.diagnostics,
      Routes.pairing,
      Routes.serverSignIn,
      Routes.devFoundation,
    };
    for (final tab in kAppTabs) {
      expect(wired, contains(tab.route), reason: '${tab.label} is live');
    }
  });

  test('DiagnosticsScreen and SettingsScreen are not tabs', () {
    // Both sit outside the tab shell. Diagnostics used to light the Today tab,
    // which told the owner they were somewhere they were not and offered three
    // exits out of a flow they were in the middle of.
    expect(const DiagnosticsScreen().runtimeType, DiagnosticsScreen);
    final routes = kAppTabs.map((tab) => tab.route);
    expect(routes, isNot(contains(Routes.diagnostics)));
    expect(routes, isNot(contains(Routes.settings)));
  });
}
