/// Routes. One route today; the shape of the five-tab shell is already decided.
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
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  /// The outcome ledger — what is actually working.
  static const String insights = '/insights';

  /// Challenges and commitments.
  static const String actions = '/actions';

  /// Identity, body, appearance, data and sync.
  static const String profile = '/profile';
}

/// The app's router.
///
/// Only [Routes.today] is wired, and it renders the foundation placeholder. The
/// remaining constants above are the agreed paths, not dead routes — a route with
/// no screen would be a link to a crash, so they are added with their screens.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.today,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.today,
        builder: (BuildContext context, GoRouterState state) => const FoundationScreen(),
      ),
    ],
  );
}
