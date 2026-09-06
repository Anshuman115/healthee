/// Routes. Five tabs, the setup surfaces, and settings outside the shell.
///
/// `docs/APP_DESIGN.md` §2 fixes the information architecture — five tabs (Today ·
/// Sleep · Activity · Insights · Actions), a Coach FAB on Today, and the owner's
/// own surfaces off the Today avatar rather than as a sixth tab. All five tabs and
/// the avatar's destination now exist; `core/tabs.dart` records what changed and
/// why.
///
/// go_router rather than `Navigator` calls: deep links (a notification opening one
/// night's sleep detail) and typed paths are both things the app will need, and
/// retrofitting a router after screens exist means touching every screen.
///
/// ## The five tabs are BRANCHES, not sibling pages
///
/// They were plain sibling `GoRoute`s, which meant every tab switch built a new
/// page and threw the old one away — scroll offset, chart reveals and provider
/// reads with it. `shared/app_shell.dart` records the measurement. They are now
/// the branches of a `StatefulShellRoute.indexedStack`, each with its own
/// `Navigator`, all kept alive — which is also what gives the Android back button
/// a per-tab stack to pop (the shell owns that rule).
///
/// ## `go` REPLACES. Every out-of-shell destination is pushed.
///
/// This shipped wrong once and the bug is worth stating in full, because the
/// mistake reads as correct: `context.go` replaces the location rather than
/// stacking on it, so a `go` into Settings left **nothing underneath**. The
/// shell's back rule then did exactly what it says — an empty branch stack, not
/// on Today, so leave — and the owner was dropped onto the Android home screen
/// from a screen they had tapped into two seconds earlier. Every out-of-shell
/// route had it, so Settings → Diagnostics → back left the app too.
///
/// The rule, and it is a rule rather than a case-by-case judgement:
///
/// | navigation | verb | why |
/// |---|---|---|
/// | tab → tab (`app_tab_bar.dart`) | `go` | a bar switches between siblings; stacking them would make back walk a history of tabs |
/// | Today → settings · sign-in | `push` | a destination the owner came from somewhere and expects to return to |
/// | settings → diagnostics · sign-in · pairing | `push` | back lands on Settings, which is what made it findable |
/// | the redirect below | replace | there is nothing to return to |
///
/// **`push` is also what draws the back arrow.** A `go`-ed screen with an
/// `AppBar` has no leading control, so those screens offered no way back at all
/// — not even a wrong one. The gesture and the affordance were missing together,
/// which is why nothing on screen looked broken.
///
/// [leaveSetup] handles the one place the two columns meet: a setup flow that
/// may be pushed *or* redirected into.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/settings_routes.dart';
import 'package:healthee/core/tabs.dart';
import 'package:healthee/data/pairing/pairing_repository.dart';
import 'package:healthee/features/actions/challenge_detail_screen.dart';
import 'package:healthee/features/actions/outcomes_screen.dart';
import 'package:healthee/features/actions/program_detail_screen.dart';
import 'package:healthee/features/actions/recommendation_history_screen.dart';
import 'package:healthee/features/gps/gps_screen.dart';
import 'package:healthee/features/gps/route_detail_screen.dart';
import 'package:healthee/features/gps/routes_screen.dart';
import 'package:healthee/features/history/history_screen.dart';
import 'package:healthee/features/workouts/workout_detail_screen.dart';
import 'package:healthee/features/workouts/workout_history_screen.dart';
import 'package:healthee/shared/app_shell.dart';
import 'package:healthee/shared/foundation_screen.dart';

/// Every route's path, in one place. Screens reference these, never string
/// literals — Standards §3 bans the string-literal habit for user constants and
/// the reasoning is the same here: a typo'd path fails at runtime, a typo'd
/// constant fails at compile time.
abstract final class Routes {
  static const recommendations = '/recommendations';
  static const gps = '/gps';
  static const routes = '/routes';
  static const route = '/route';
  static const String challenge = '/challenge';
  static const String program = '/program';
  static const String outcomes = '/outcomes';
  static const String workouts = '/workouts';
  static const String workout = '/workout';
  static const String profile = '/profile';

  /// Daily metric observations over selectable periods.
  static const String history = '/history';

  /// Manual observations and recent entries.
  static const String journal = '/journal';

  /// The daily snapshot. The app's home.
  static const String today = '/';

  /// Last night, and the one lever to improve tonight.
  static const String sleep = '/sleep';

  /// Fitness, organised around VO₂max.
  static const String activity = '/activity';

  /// The owner's own history — trends, and the patterns found in it.
  ///
  /// There is no `/coach` path. The coach is a sheet opened from Today's FAB
  /// (`features/coach/coach_sheet.dart`), which is where legacy puts it and what
  /// `docs/APP_DESIGN.md` §2 describes; a route for it would be a second way in
  /// with a different back behaviour.
  static const String insights = '/insights';

  /// Every cited action the server raised for today.
  static const String actions = '/actions';

  /// Appearance, the server session, the strap, diagnostics and the licences.
  ///
  /// **Outside the tab shell**, and reached from the Today header's avatar —
  /// which is the entry point that already existed, extended rather than
  /// duplicated. A settings surface inside the bar would light a tab while the
  /// owner is somewhere that is not a tab.
  static const String settings = '/settings';

  /// Light · Dark · System, and the accent this build wears.
  ///
  /// ## The sub-screens are paths under [settings], not flags on it
  ///
  /// The v02 design turns Settings from one long scroll of expanding cards into
  /// an **index of rows**, each opening a screen of its own. A boolean on the
  /// settings screen saying "show the appearance panel" would be a route the
  /// router does not know about: no deep link, no back arrow, and a system back
  /// gesture that leaves the app instead of closing the panel.
  ///
  /// They nest under `/settings` because that is what they are under, and
  /// because a `push` from the index then pops back to the index — which is the
  /// same rule `leaveSetup` keeps for the two setup flows.
  static const String appearance = '/settings/appearance';

  /// The three optional nudges, and the times they arrive at.
  static const String reminders = '/settings/reminders';

  /// Whether the phone collects and uploads on its own, and under what limits.
  static const String background = '/settings/background';

  /// The strap this phone is paired to: its charge, its last read, its sync.
  static const String device = '/settings/device';

  /// Which streams are current, and how old each one is.
  static const String dataFreshness = '/settings/sync';

  /// What this app is, which build it is, and the licences it carries.
  static const String about = '/settings/about';

  /// The first screen an app with nothing set up has to show.
  ///
  /// Not reached by a redirect — the router still sends a strapless app to
  /// [pairing], which is the flow that gets it working. This is the door
  /// **into** that flow, and the account screen beside it.
  static const String welcome = '/welcome';

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
/// Every path in [Routes] is wired to a screen. That is not a coincidence to be
/// maintained by review — `test/features/reachability_test.dart` walks the tab
/// list against the wired set, because a tab pointing at an unregistered path
/// looks like nothing at all until somebody taps it.
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
      if (summary.value?.strap == null &&
          state.matchedLocation != Routes.pairing) {
        return Routes.pairing;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.recommendations,
        builder: (context, state) => const RecommendationHistoryScreen(),
      ),
      GoRoute(path: Routes.gps, builder: (context, state) => const GpsScreen()),
      GoRoute(
        path: Routes.routes,
        builder: (context, state) => const RoutesScreen(),
      ),
      GoRoute(
        path: '${Routes.route}/:id',
        builder: (context, state) =>
            RouteDetailScreen(id: state.pathParameters['id']!),
      ),
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
        path: Routes.devFoundation,
        builder: (BuildContext context, GoRouterState state) =>
            const FoundationScreen(),
      ),
      GoRoute(
        path: '${Routes.challenge}/:id',
        builder: (context, state) => ChallengeDetailScreen(
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: '${Routes.program}/:id',
        builder: (context, state) => ProgramDetailScreen(
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
      GoRoute(
        path: Routes.outcomes,
        builder: (context, state) => const OutcomesScreen(),
      ),
      GoRoute(
        path: Routes.workouts,
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),
      GoRoute(
        path: Routes.workout,
        builder: (context, state) => WorkoutDetailScreen(
          start: state.uri.queryParameters['start'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.history,
        builder: (context, state) =>
            HistoryScreen(initialMetric: state.uri.queryParameters['metric']),
      ),
      ...settingsRoutes(),
    ],
  );
}

/// Leaves a setup screen the way the owner came into it.
///
/// The two setup flows are reachable **two ways**, and "Done" cannot mean one
/// thing for both:
///
///   * **Pushed** from Settings, by somebody who went looking for it. There is a
///     screen underneath and they expect to come back to it, so Done pops.
///   * **Redirected into** by the router, because the app holds no strap
///     credentials and has nothing to show. Nothing is underneath, so Done goes
///     to Today — which the redirect will now allow, because pairing succeeded.
///
/// `canPop()` is the question that distinguishes them, and it is the router's
/// own rather than a flag threaded down through the screens: a parameter saying
/// "you were pushed" is a second copy of a fact the navigator already holds, and
/// it would be wrong the first time a third caller forgot to set it.
void leaveSetup(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.today);
  }
}

/// Lets [buildRouter] tell go_router that the pairing state moved.
/// `notifyListeners` is protected, so poking a bare `ChangeNotifier` from
/// outside is not something the analyzer allows — this is the sanctioned shape.
class _RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}
