/// The app frame the four tabs live in: one `Scaffold`, one bar, four branches.
///
/// This is the widget half of `StatefulShellRoute.indexedStack` (wired in
/// `core/router.dart`). The shell owns the only [AppTabBar] in the app and the
/// only `Scaffold` that has one; `navigationShell` is an `IndexedStack` of four
/// `Navigator`s, each keeping its own widget tree, scroll offsets and route stack
/// alive while the others are shown.
///
/// ## What the indexed stack buys, measured
///
/// Before this, each tab was a plain `GoRoute` and a tab switch built a new page:
/// scrolling Today two screenfuls, tapping Sleep and tapping Today put Today back
/// at the top. Three things went with the scroll offset, and only one of them was
/// visible:
///
///   * every `RevealOnce` chart animated again — CLAUDE.md's rule is that charts
///     must not replay, and the widget was holding it correctly while the
///     navigation layer discarded the registry it holds it in;
///   * provider reads re-ran, so a tab switch could re-hit the network;
///   * there was no per-tab back stack, so Android back did not do what a tab bar
///     implies.
///
/// ## The bar is in the `bottomNavigationBar` slot, not over the content
///
/// So the body is **laid out above** the bar rather than under it, which is what
/// keeps the last card off it; the bar's own `SafeArea` then adds the gesture
/// inset beneath the icons. A bar floating over the scroll would need every list
/// to know its height, which is one more number to get wrong per screen.
///
/// ## What is deliberately OUTSIDE the shell
///
/// Pairing, server sign-in and `/diagnostics` are full-screen routes with no tab
/// bar. Pairing and sign-in are setup flows the app redirects into — a bar
/// offering four destinations to somebody who has not paired a strap offers four
/// empty screens. Diagnostics is the "is the instrument working" surface reached
/// from pairing; it belongs to that flow, and lighting a tab on it (it used to
/// light Today) said the owner was somewhere they were not.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/shared/app_tab_bar.dart';

/// The tab frame: the shell's current branch, over the one bar.
class AppShell extends StatelessWidget {
  /// [navigationShell] is go_router's branch container.
  const AppShell({required this.navigationShell, super.key});

  /// The indexed stack of branch navigators, and the API to move between them.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppTabBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          // Pressing the tab you are already on resets that branch to its root,
          // which is the one thing a bottom bar universally means. Pressing any
          // other tab keeps the branch exactly as it was left.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
