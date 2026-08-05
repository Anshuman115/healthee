/// The tab registry — ONE list, read by the bar and by the router's branches.
///
/// ## Why this is not a constant inside the bar widget
///
/// A `StatefulShellRoute.indexedStack` has an ordered list of branches and the
/// bar has an ordered list of items, and the two are joined by **index**:
/// `navigationShell.goBranch(i)` means "the i-th branch", not "the route named
/// on the i-th tab". Two lists in two files joined by an integer is a defect
/// waiting for somebody to insert a tab — the bar would light one screen and open
/// another, and nothing would fail to compile. So there is one list, and the
/// router builds its branches by iterating it.
///
/// That is also why [AppTab.screen] is here rather than a `switch` in the router:
/// a switch over routes needs an unreachable default, and an unreachable default
/// is a runtime error where a missing field would have been a compile error.
///
/// ## Four tabs, not five — Actions came OUT of the bar
///
/// `docs/APP_DESIGN.md` §2 names five (Today · Sleep · Activity · Insights ·
/// Actions) and this bar drew all five, with Actions dimmed and inert because it
/// has no screen. That is the wrong shape for a **navigation control**, and the
/// argument that put it there confused two different rules:
///
///   * *"Show the shape, say it is not there"* is about a missing **number**. The
///     reader is already on the screen, the card is the shape, and the sentence
///     under it is the whole answer.
///   * A tab is not a shape, it is a **promise of a destination**. There is no
///     wording available inside a 10 pt label to keep that promise honest, and a
///     control in the primary navigation that never responds teaches the owner
///     that controls in this app may not respond — which is a cost paid on every
///     other tap, forever.
///
/// A near-empty Actions screen was the alternative and was rejected as worse: it
/// would be a fifth destination that answers nothing, and today's cited actions
/// already have a home — Today's "Suggested today". Actions returns to this list
/// in the commit that ships its screen, which is one entry and one branch.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/coach/coach_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/today/today_screen.dart';

/// One tab: what it is called, its icon, its route, and the screen behind it.
@immutable
class AppTab {
  /// A tab in the bar. Every field is required — see the library docstring on
  /// why a tab with no destination is not a thing this list can express.
  const AppTab({
    required this.label,
    required this.icon,
    required this.route,
    required this.screen,
  });

  /// The name under the icon.
  final String label;

  /// The icon above it.
  final IconData icon;

  /// The branch's root path. Deep links and `context.go` use it; the bar does
  /// not — it moves by branch index.
  final String route;

  /// Builds the tab's screen. The router calls it once per branch.
  final Widget Function() screen;
}

/// The tabs, in bar order — which is also branch order. See the docstring.
///
/// Coach sits where `docs/APP_DESIGN.md` puts a FAB on Today. It is in the bar
/// because the legacy bar this rebuild is matching has its fifth item there, and
/// the findings live on it.
const List<AppTab> kAppTabs = <AppTab>[
  AppTab(
    label: 'Today',
    icon: Icons.wb_sunny_outlined,
    route: Routes.today,
    screen: TodayScreen.new,
  ),
  AppTab(
    label: 'Sleep',
    icon: Icons.nightlight_outlined,
    route: Routes.sleep,
    screen: SleepScreen.new,
  ),
  AppTab(
    label: 'Activity',
    icon: Icons.show_chart,
    route: Routes.activity,
    screen: ActivityScreen.new,
  ),
  AppTab(
    label: 'Coach',
    icon: Icons.forum_outlined,
    route: Routes.coach,
    screen: CoachScreen.new,
  ),
];
