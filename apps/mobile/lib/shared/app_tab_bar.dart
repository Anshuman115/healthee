/// The five-tab bar every legacy screen sits on — Today · Sleep · Activity ·
/// Coach · Actions.
///
/// **Ported from** the bottom bar visible in every `design_reference/project/
/// screens/v2-*.png`: five icon-over-label items on the app frame, the active one
/// in the accent, the rest quiet.
///
/// ## A tab is live only when its screen exists
///
/// `core/router.dart` is explicit that it wires only the routes that have
/// screens: *"a route with no screen would be a link to a crash"*. Four of the
/// five now do. **Actions has not shipped**, so it is drawn dimmed,
/// non-interactive, and marked disabled to the semantics tree — a screen reader
/// says "not built yet" rather than announcing a button that does nothing.
///
/// That is the same choice the rest of this app makes about a missing number:
/// show the shape, say it is not there, do not fake the content. Two other shapes
/// were rejected — leaving the bar out entirely (it is the most recognisable
/// piece of the legacy screen, and its absence makes Today look like the whole
/// app), and routing all five to placeholder screens to make the bar look
/// finished.
///
/// Lives in `shared/` rather than under one feature: four features draw it, and
/// Standards §1 forbids a feature reaching into another feature's widgets.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// One tab: what it is called, its icon, and the route it opens.
@immutable
class AppTab {
  /// A tab in the bar. [route] is null until the tab's screen ships.
  const AppTab({required this.label, required this.icon, this.route});

  /// The name under the icon.
  final String label;

  /// The icon above it.
  final IconData icon;

  /// Where tapping it goes, or null when there is nowhere to go yet.
  final String? route;

  /// False until the tab's screen ships. See the library docstring.
  bool get built => route != null;
}

/// The five tabs, in `docs/APP_DESIGN.md` §2's order.
///
/// Coach sits where the design doc puts a FAB on Today. It is in the bar because
/// legacy's bar has five items and this one is a picture of legacy's bar.
const List<AppTab> kAppTabs = <AppTab>[
  AppTab(label: 'Today', icon: Icons.wb_sunny_outlined, route: Routes.today),
  AppTab(label: 'Sleep', icon: Icons.nightlight_outlined, route: Routes.sleep),
  AppTab(label: 'Activity', icon: Icons.show_chart, route: Routes.activity),
  AppTab(label: 'Coach', icon: Icons.forum_outlined, route: Routes.coach),
  AppTab(label: 'Actions', icon: Icons.check_circle_outline),
];

/// The app frame's bottom bar.
class AppTabBar extends StatelessWidget {
  /// [currentIndex] is the tab being shown.
  const AppTabBar({required this.currentIndex, super.key});

  /// Which tab is active.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.chrome,
        border: Border(top: BorderSide(color: colors.line2, width: hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          child: Row(
            children: [
              for (var i = 0; i < kAppTabs.length; i++)
                Expanded(
                  child: _TabItem(tab: kAppTabs[i], active: i == currentIndex),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.active});

  final AppTab tab;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tint = switch ((tab.built, active)) {
      (false, _) => colors.ink3.withValues(alpha: 0.45),
      (true, true) => colors.accent,
      (true, false) => colors.ink3,
    };
    final route = tab.route;
    return Semantics(
      button: tab.built,
      enabled: tab.built,
      selected: active,
      // Named rather than left to the label alone: "Actions, dimmed" is not
      // something a screen reader can convey, and "not built yet" is the fact.
      label: tab.built ? tab.label : '${tab.label} — not built yet',
      child: ExcludeSemantics(
        child: InkWell(
          // The active tab is not a no-op link to itself, and an unbuilt tab has
          // nowhere to go — both take null, which is what makes them un-pressable
          // rather than pressable-and-inert.
          onTap: route == null || active ? null : () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 20, color: tint),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  style: text.labelSmall?.copyWith(color: tint, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
