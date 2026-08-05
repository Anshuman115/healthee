/// The header row: today's date, the theme toggle, and the way to the pairing.
///
/// **Ported from** `design_reference/project/hh/screen_today.jsx`'s
/// `GreetingHeader` — an eyebrow date on the left, a 38 px circular theme toggle
/// and a 38 px circular avatar on the right. There is no app bar above it; the
/// legacy screen begins with this row inside the scroll, which is what gives
/// Today its full-bleed opening instead of a title bar saying the name of the tab
/// the owner is already on.
///
/// ## Two departures, both because this app has less to say than the mockup did
///
/// **The avatar has no initial.** Legacy drew "M" for Maya. Nothing in this app
/// stores an owner name — not the pairing record, not the payload — so an initial
/// would be a character invented to fill a circle. It draws a person outline
/// instead, and goes to [Routes.settings] — which is the surface it was always
/// standing in for. It used to open the pairing screen, which is why that screen
/// had grown a "Your server" card and an "Open diagnostics" card that are not
/// about pairing; those rows moved to settings and the avatar now goes straight
/// there. It is still ONE entry point, extended rather than duplicated.
///
/// **The toggle sets an explicit mode.** It lives in `shared/page_head.dart` now,
/// because every other screen's header has one too; the reasoning moved with it.
/// The settings screen has an appearance row over the same provider — one state,
/// two controls, no copy.
///
/// **The connection dot is the quiet half of the connection surface.** Seven
/// pixels beside the date, drawn only when `ConnectionHealth.quiet` is true;
/// otherwise the full strip is already above this row and drawing a second mark
/// here would be the same fact twice.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/sync/connection_health.dart';
import 'package:healthee/shared/connection/connection_dot.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/page_head.dart';

/// Today's date, the connection dot, and the two controls beside them.
class TodayHeader extends StatelessWidget {
  /// [now] is injected so the date does not read the wall clock in a test.
  const TodayHeader({this.now, this.health, super.key});

  /// The instant the date is taken from.
  final DateTime? now;

  /// The classified connection state, or null when nothing has classified one —
  /// a widget test pumping this row alone. Null draws no dot rather than a
  /// reassuring one.
  final ConnectionHealth? health;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ModuleLabel(longDateLabel(now ?? DateTime.now())),
        if (health case final ConnectionHealth state when state.quiet) ...[
          const SizedBox(width: Insets.sm),
          ConnectionDot(live: state.live, semanticLabel: state.report.headline),
        ],
        const Spacer(),
        const ThemeToggleButton(),
        const SizedBox(width: Insets.sm + 2),
        const _AvatarButton(),
      ],
    );
  }
}

/// `THURSDAY, AUGUST 4` — legacy's eyebrow, spelled out.
///
/// Built from `const` name tables rather than `intl`: the app has no localisation
/// and adding a package to format one string would be a dependency for a label.
String longDateLabel(DateTime at) {
  const days = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  const months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${days[at.weekday - 1]}, ${months[at.month - 1]} ${at.day}';
}

/// The way to the strap this app is paired to. See the library docstring.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: Icons.person_outline,
      semanticLabel: 'Settings',
      onPressed: () => context.go(Routes.settings),
    );
  }
}
