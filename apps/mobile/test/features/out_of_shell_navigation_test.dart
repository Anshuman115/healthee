/// Every door OUT of the tab shell, and the way back in through it.
///
/// `back_navigation_test.dart` covers the rule inside the shell — pop a route
/// pushed in a branch, non-Today → Today, Today → exit. That rule was right and
/// shipped broken anyway, because everything it governs lives *inside* the shell
/// and every screen the avatar opens lives outside it.
///
/// **`context.go` REPLACES the location.** A `go` into Settings left nothing
/// beneath it, so the shell's rule found an empty branch stack, correctly
/// concluded "not on Today", and left the app — from a screen the owner had
/// tapped into two seconds earlier. Settings → Diagnostics → back left the app
/// too. Found on a device; this suite is the half that was missing.
///
/// The other half of the same defect is that a `go`-ed screen with an `AppBar`
/// has no leading control, so these screens offered no way back **at all** —
/// not a wrong one, none. The gesture and the affordance went missing together,
/// which is why nothing on screen looked broken.
///
/// `test/mutations.sh` flips each `push` back to `go` and requires this file to
/// go red. That check is what was not there when it shipped.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/pairing/pairing_screen.dart';
import 'package:healthee/features/settings/settings_screen.dart';
import 'package:healthee/features/signin/server_signin_screen.dart';
import 'package:healthee/features/today/today_screen.dart';

import '_today_host.dart';

/// Records every `SystemNavigator.pop` the app sends while a test runs.
///
/// Filtered to that one method: the platform channel also carries `SystemChrome`
/// and `SystemSound` traffic the framework sends on its own, and a list of
/// everything would make "nothing happened" impossible to assert.
List<String> _watchPlatformCalls(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') {
        calls.add(call.method);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// Sends one system back press, the way the platform does.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  group('OUT OF THE SHELL — every door the avatar opens comes back', () {
    /// A viewport tall enough to hold the whole settings screen.
    ///
    /// The default 800x600 leaves the lower rows BUILT but below the fold, so
    /// `scrollUntilVisible` reports success without moving and the tap then lands
    /// outside the render tree — a silent miss that reads as "the button does
    /// nothing". `reachability_test.dart` documents the same trap. A taller
    /// window is the honest fix: what is asserted here is where a row GOES, not
    /// that it fits above the fold.
    void tallViewport(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(420, 2400)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    /// Opens Settings the way the owner does: the person outline in the header.
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
    }

    /// Taps a settings row by its button label, scrolling to it first.
    Future<void> tapRow(WidgetTester tester, String label) async {
      final button = find.widgetWithText(OutlinedButton, label);
      await tester.scrollUntilVisible(button, 300);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('BACK FROM SETTINGS LANDS ON TODAY AND DOES NOT EXIT', (
      tester,
    ) async {
      // The reported defect, exactly: force-stop, launch, avatar, back — and the
      // owner was on the Android home screen with the process still alive.
      tallViewport(tester);
      final platform = _watchPlatformCalls(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await _pressBack(tester);

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(
        find.byType(SettingsScreen),
        findsNothing,
        reason: 'back has to leave the screen it was pressed on',
      );
      expect(
        platform,
        isNot(contains('SystemNavigator.pop')),
        reason:
            'THIS is the bug: `go` replaced the location, so the shell rule '
            'found an empty stack and correctly decided to leave the app',
      );
    });

    testWidgets('BACK FROM DIAGNOSTICS LANDS ON SETTINGS, NOT TODAY', (
      tester,
    ) async {
      // Two levels out of the shell. Settings is the only thing that makes
      // diagnostics findable, so returning to Today would lose the owner's place
      // in the surface they were working through.
      tallViewport(tester);
      final platform = _watchPlatformCalls(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tapRow(tester, 'Open diagnostics');
      expect(find.byType(DiagnosticsScreen), findsOneWidget);

      await _pressBack(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
      expect(platform, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('and a second back from there lands on Today', (tester) async {
      // The whole stack unwinds one screen at a time. A `pushReplacement`
      // anywhere in it would skip a level and look almost right.
      tallViewport(tester);
      final platform = _watchPlatformCalls(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tapRow(tester, 'Open diagnostics');

      await _pressBack(tester);
      await _pressBack(tester);

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(platform, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('back from the pairing screen returns to Settings', (
      tester,
    ) async {
      tallViewport(tester);
      final platform = _watchPlatformCalls(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tapRow(tester, 'Pairing and unpair');
      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.byType(PairingScreen), findsOneWidget);

      await _pressBack(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(platform, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('back from the sign-in screen returns to Settings', (
      tester,
    ) async {
      tallViewport(tester);
      final platform = _watchPlatformCalls(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);
      // The label is the signed-in one, because `routedApp` holds a session.
      // `server_setting.dart` names what is behind the button rather than
      // saying "Manage", so the two states have two labels.
      await tapRow(tester, 'Sign out or change server');
      expect(find.byType(ServerSignInScreen), findsOneWidget);

      await _pressBack(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(platform, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('DONE ON A PUSHED SETUP FLOW RETURNS TO SETTINGS', (
      tester,
    ) async {
      // "Done" cannot mean one thing for both ways in. Pushed from Settings it
      // has a screen underneath and must pop to it; redirected into by an
      // unpaired app it has nothing underneath and must go to Today.
      // `router.dart::leaveSetup` asks `canPop()` rather than being told.
      tallViewport(tester);
      final platform = _watchPlatformCalls(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tapRow(tester, 'Pairing and unpair');
      expect(find.byType(PairingScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(
        find.byType(SettingsScreen),
        findsOneWidget,
        reason: 'hard-coding the redirect\'s answer throws away the screen '
            'underneath, which looks correct until pairing is opened from here',
      );
      expect(platform, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('EVERY OUT-OF-SHELL SCREEN DRAWS A BACK ARROW', (tester) async {
      // The other half of the defect, and the reason nothing looked wrong: a
      // `go`-ed screen with an `AppBar` has no leading control, so these screens
      // offered no way back AT ALL — not a wrong one, none. The gesture and the
      // affordance went missing together.
      tallViewport(tester);
      await tester.pumpWidget(routedApp(store));
      await tester.pumpAndSettle();
      await openSettings(tester);

      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('leaving a setup flow the way you came into it', () {
    /// A router whose setup screen is either pushed onto a home or IS the
    /// initial location — the two ways `/pairing` is actually reached.
    Widget host({required bool pushed, required List<String> landed}) {
      final router = GoRouter(
        initialLocation: pushed ? '/home' : '/setup',
        routes: <RouteBase>[
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(context.push('/setup')),
                child: const Text('open setup'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.today,
            builder: (context, state) {
              landed.add(Routes.today);
              return const Scaffold(body: Text('today'));
            },
          ),
          GoRoute(
            path: '/setup',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => leaveSetup(context),
                child: const Text('done'),
              ),
            ),
          ),
        ],
      );
      return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
    }

    testWidgets('PUSHED: done pops back to what opened it', (tester) async {
      final landed = <String>[];
      await tester.pumpWidget(host(pushed: true, landed: landed));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open setup'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();

      expect(find.text('open setup'), findsOneWidget);
      expect(
        landed,
        isEmpty,
        reason: 'Today is not where this owner came from',
      );
    });

    testWidgets('REDIRECTED INTO: done goes to Today, because nothing is under it', (
      tester,
    ) async {
      final landed = <String>[];
      await tester.pumpWidget(host(pushed: false, landed: landed));
      await tester.pumpAndSettle();

      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();

      expect(find.text('today'), findsOneWidget);
      expect(landed, <String>[Routes.today]);
    });
  });
}
