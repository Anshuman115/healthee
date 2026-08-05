/// Routes. Four tabs, the pairing surfaces, and the diagnostics behind them.
///
/// `docs/APP_DESIGN.md` §2 fixes the information architecture — five tabs (Today ·
/// Sleep · Activity · Insights · Actions), a Coach FAB on Today, and Profile as a
/// right-slide route off the Today avatar rather than a sixth tab. The paths below
/// are those names, so a screen landing tomorrow attaches to a route that already
/// exists instead of inventing a URL scheme.
///
/// go_router rather than `Navigator` calls: deep links (a notification opening one
/// night's sleep detail) and typed paths are both things the app will need, and
/// retrofitting a router after screens exist means touching every screen.
///
/// ## The four tabs are BRANCHES, not sibling pages
///
/// They were plain sibling `GoRoute`s, which meant every tab switch built a new
/// page and threw the old one away — scroll offset, chart reveals and provider
/// reads with it. `shared/app_shell.dart` records the measurement. They are now
/// the branches of a `StatefulShellRoute.indexedStack`, each with its own
/// `Navigator`, all kept alive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/tabs.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/pairing/pairing_screen.dart';
import 'package:healthee/features/signin/server_signin_screen.dart';
import 'package:healthee/shared/app_shell.dart';
import 'package:healthee/shared/foundation_screen.dart';

/// Every route's path, in one place. Screens reference these, never string
/// literals — Standards §3 bans the string-literal habit for user constants and
/// the reasoning is the same here: a typo'd path fails at runtime, a typo'd
/// constant fails at compile time.
abstract final class Routes {
  /// The daily snapshot. The app's home.
  static const String today = '/';

  /// Last night, and the one lever to improve tonight.
  static const String sleep = '/sleep';

  /// Fitness, organised around VO₂max.
  static const String activity = '/activity';

  /// The coach, and — until it ships — the findings in the owner's own data.
  static const String coach = '/coach';

  /// Challenges and commitments.
  static const String actions = '/actions';

  /// Identity, body, appearance, data and sync.
  static const String profile = '/profile';

  /// Pair a strap, or review the pairing already held.
  static const String pairing = '/pairing';

  /// Baselines and the strap's own streams — "is the instrument working".
  ///
  /// Off the tab bar on purpose. `diagnostics_screen.dart` argues it: these are
  /// the numbers the owner wants when something looks wrong, and never at 7am.
  /// Reached from [pairing], which is where the avatar on Today already goes.
  static const String diagnostics = '/diagnostics';

  /// Sign in to the Healthee server, or review the session already held.
  ///
  /// **Nothing redirects here**, unlike [pairing]. See the router's own
  /// "Unpaired means pairing" note for the contrast: an app with no strap has
  /// nothing to show at all, whereas an app with no server session still has
  /// every measurement this phone read off the strap. Gating on a token would
  /// take the owner's own data away until they satisfied a server, and
  /// strap-only is a supported mode rather than a degraded one.
  static const String serverSignIn = '/server';

  /// The honesty-state specimen sheet. **Not a product screen.**
  ///
  /// `FoundationScreen` used to sit on [today], where it was reasonably
  /// mistaken for a hung request — a catalogue whose loading specimen looks
  /// exactly like a screen that never loaded. It is kept because it is a useful
  /// side-by-side of the four `Reading` states while building a card, and it is
  /// kept OFF the home route for the same reason it was moved.
  static const String devFoundation = '/dev/foundation';
}

/// The app's router.
///
/// Everything above is wired except [Routes.actions] and [Routes.profile], which
/// have no screens. They are the agreed paths, not dead routes — a route with no
/// screen would be a link to a crash, so they are added with their screens.
/// Actions is also **not in the bar** until then; `core/tabs.dart` argues why a
/// dimmed, inert tab is worse than four tabs.
///
/// ## Unpaired means pairing
///
/// An app holding no strap credentials has nothing to show and nothing to sync,
/// so the redirect sends it to [Routes.pairing]. Two states deliberately do NOT
/// redirect: while the keystore read is still in flight (a redirect on unknown
/// state flashes the pairing screen at an owner who is already paired), and when
/// that read failed (we do not know, and locking someone out of their own cached
/// data on a keystore hiccup would be the wrong way to be wrong). Both are
/// logged by `ProviderLogger`; neither is guessed at.
GoRouter buildRouter(WidgetRef ref) {
  // The keystore read is asynchronous, so the first redirect always runs on
  // `loading`. Without this the router would never look again and an unpaired
  // app would sit on a screen it has no data for.
  final refresh = _RouterRefresh();
  ref.listenManual(pairingSummaryProvider, (previous, next) => refresh.bump());

  return GoRouter(
    initialLocation: Routes.today,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final summary = ref.read(pairingSummaryProvider);
      if (summary.isLoading || summary.hasError) {
        return null;
      }
      if (summary.value?.strap == null && state.matchedLocation != Routes.pairing) {
        return Routes.pairing;
      }
      return null;
    },
    routes: <RouteBase>[
      // The tabs. Branch order IS `kAppTabs` order, by construction rather than
      // by agreement — the bar moves by index, so two lists would be a defect
      // that compiles.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          for (final AppTab tab in kAppTabs)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: tab.route,
                  builder: (BuildContext context, GoRouterState state) =>
                      tab.screen(),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: Routes.diagnostics,
        builder: (BuildContext context, GoRouterState state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: Routes.devFoundation,
        builder: (BuildContext context, GoRouterState state) => const FoundationScreen(),
      ),
      GoRoute(
        path: Routes.pairing,
        builder: (BuildContext context, GoRouterState state) =>
            PairingScreen(onDone: () => context.go(Routes.today)),
      ),
      GoRoute(
        path: Routes.serverSignIn,
        builder: (BuildContext context, GoRouterState state) =>
            ServerSignInScreen(onDone: () => context.go(Routes.today)),
      ),
    ],
  );
}

/// Lets [buildRouter] tell go_router that the pairing state moved.
/// `notifyListeners` is protected, so poking a bare `ChangeNotifier` from
/// outside is not something the analyzer allows — this is the sanctioned shape.
class _RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}
