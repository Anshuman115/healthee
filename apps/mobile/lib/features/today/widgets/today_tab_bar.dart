/// The five-tab bar every legacy screen sits on — Today · Sleep · Activity ·
/// Coach · Actions.
///
/// **Ported from** the bottom bar visible in every `design_reference/project/
/// screens/v2-*.png`: five icon-over-label items on the app frame, the active one
/// in the accent, the rest quiet.
///
/// ## Four of the five have no screen, and this says so rather than pretending
///
/// `core/router.dart` fixes the information architecture and is explicit that it
/// wires only the routes that have screens: *"a route with no screen would be a
/// link to a crash"*. Sleep, Activity, Coach and Actions have not shipped.
///
/// Three shapes were considered and two were rejected:
///
///   * **Leave the bar out until the tabs exist.** It is the most recognisable
///     piece of the legacy screen, and its absence makes Today look like the
///     whole app rather than one of five.
///   * **Show all five as live and route them.** That is a link to a crash, or —
///     barely better — four placeholder screens shipped to make a bar look
///     finished.
///
/// So the bar is drawn in full and the four unbuilt tabs are **visibly not
/// ready**: dimmed, non-interactive, and marked as disabled to the semantics tree
/// so a screen reader says so rather than announcing a button that does nothing.
/// That is the same choice the rest of this app makes about a missing number —
/// show the shape, say it is not there, do not fake the content.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';

/// One tab: what it is called, its icon, and whether its screen exists.
@immutable
class TodayTab {
  /// A tab in the bar.
  const TodayTab({required this.label, required this.icon, required this.built});

  /// The name under the icon.
  final String label;

  /// The icon above it.
  final IconData icon;

  /// False until the tab's screen ships. See the library docstring.
  final bool built;
}

/// The five tabs, in `docs/APP_DESIGN.md` §2's order.
///
/// Coach sits where the design doc puts a FAB on Today. It is in the bar because
/// legacy's bar has five items and this one is a picture of legacy's bar; when
/// the Coach surface ships, whether it is a tab or a FAB is that PR's decision.
const List<TodayTab> kTodayTabs = <TodayTab>[
  TodayTab(label: 'Today', icon: Icons.wb_sunny_outlined, built: true),
  TodayTab(label: 'Sleep', icon: Icons.nightlight_outlined, built: false),
  TodayTab(label: 'Activity', icon: Icons.show_chart, built: false),
  TodayTab(label: 'Coach', icon: Icons.forum_outlined, built: false),
  TodayTab(label: 'Actions', icon: Icons.check_circle_outline, built: false),
];

/// The app frame's bottom bar.
class TodayTabBar extends StatelessWidget {
  /// [currentIndex] is the tab being shown. Only `0` has a screen today.
  const TodayTabBar({this.currentIndex = 0, super.key});

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
              for (var i = 0; i < kTodayTabs.length; i++)
                Expanded(
                  child: _TabItem(
                    tab: kTodayTabs[i],
                    active: i == currentIndex,
                  ),
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

  final TodayTab tab;
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
    return Semantics(
      button: tab.built,
      enabled: tab.built,
      selected: active,
      // Named rather than left to the label alone: "Sleep, dimmed" is not
      // something a screen reader can convey, and "not built yet" is the fact.
      label: tab.built ? tab.label : '${tab.label} — not built yet',
      child: ExcludeSemantics(
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
    );
  }
}
