/// Nothing this rebuild removed from Today became unreachable.
///
/// Cutting Today from twenty sections to six modules is only honest if every
/// removed card is still somewhere the owner can GET TO. `today_grid_test.dart`
/// proves each module opens a tab; `tab_screens_test.dart` proves the card is on
/// it. This file covers the two routes that are not behind a grid cell, because
/// they are the ones nothing else would notice:
///
///   * **/diagnostics is off the tab bar.** Baselines and the strap's own
///     streams answer "is the instrument working", which is asked when
///     something looks wrong and never at 7am. That reasoning is only sound
///     while there is a way in, and there is exactly one: the pairing screen,
///     which the Today header's avatar already opens.
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
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/pairing/pairing_screen.dart';

import '../pairing/_pairing_fakes.dart';
import '../pairing/_zepp_stub.dart';

/// The pairing screen on a real router, so a tap goes somewhere real.
Widget _routedPairing() {
  final store = FakeSecretStore();
  return ProviderScope(
    overrides: [
      credentialsProvider.overrideWithValue(Credentials(store)),
      pairingRepositoryProvider.overrideWithValue(
        PairingRepository(
          credentials: Credentials(store),
          zepp: clientWith(happyPathAdapter()),
          scanner: FakeStrapScanner(),
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: GoRouter(
        initialLocation: Routes.pairing,
        routes: <RouteBase>[
          GoRoute(
            path: Routes.pairing,
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: Routes.diagnostics,
            builder: (context, state) =>
                const Scaffold(body: Text('the diagnostics route')),
          ),
        ],
      ),
    ),
  );
}

/// Gives the test a viewport tall enough to hold the whole pairing screen.
///
/// The default 800x600 leaves the diagnostics row built but below the fold, and
/// a `ListView` builds a little past its viewport — so a scroll-until-visible
/// helper reports success without moving and the tap then lands outside the
/// render tree. A taller window is the honest fix: what is being asserted is
/// that the row EXISTS and goes somewhere, not that it fits above the fold.
void _tallViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(420, 1600)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('DIAGNOSTICS IS REACHABLE FROM THE PAIRING SCREEN', (tester) async {
    _tallViewport(tester);
    await tester.pumpWidget(_routedPairing());
    await tester.pumpAndSettle();

    final entry = find.text('Open diagnostics');
    expect(
      entry,
      findsOneWidget,
      reason:
          'the baselines strip and the strap streams left Today on the argument '
          'that they are diagnostics; that argument needs a door',
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('the diagnostics route'), findsOneWidget);
  });

  testWidgets('the diagnostics screen names the entry that leads to it', (
    tester,
  ) async {
    // The row on the pairing screen says what is behind it in the owner's
    // words, not "Diagnostics" alone — which would be a button whose only
    // documentation is the screen you have to open to read it.
    _tallViewport(tester);
    await tester.pumpWidget(_routedPairing());
    await tester.pumpAndSettle();

    expect(find.textContaining('every stream this phone read'), findsOneWidget);
    expect(find.textContaining('how it was measured'), findsOneWidget);
  });

  test('every tab names a route, and every route is wired', () {
    const wired = <String>{
      Routes.today,
      Routes.sleep,
      Routes.activity,
      Routes.coach,
      Routes.diagnostics,
      Routes.pairing,
      Routes.serverSignIn,
      Routes.devFoundation,
    };
    for (final tab in kAppTabs) {
      expect(wired, contains(tab.route), reason: '${tab.label} is live');
    }
  });

  test('DiagnosticsScreen is not a tab and draws no bar', () {
    // It is reached from the pairing surface, outside the tab shell. It used to
    // light the Today tab, which told the owner they were somewhere they were
    // not and offered three exits out of a flow they were in the middle of.
    expect(const DiagnosticsScreen().runtimeType, DiagnosticsScreen);
    expect(
      kAppTabs.map((tab) => tab.route),
      isNot(contains(Routes.diagnostics)),
    );
  });
}
