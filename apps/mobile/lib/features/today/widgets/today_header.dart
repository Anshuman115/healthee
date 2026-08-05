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
/// instead, and goes to [Routes.pairing], which is the only identity surface that
/// exists. [Routes.profile] is a path with no screen, and linking to it would be
/// linking to a crash.
///
/// **The toggle sets an explicit mode.** It lives in `shared/page_head.dart` now,
/// because every other screen's header has one too; the reasoning moved with it.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/page_head.dart';

/// Today's date, and the two controls that sit beside it.
class TodayHeader extends StatelessWidget {
  /// [now] is injected so the date does not read the wall clock in a test.
  const TodayHeader({this.now, super.key});

  /// The instant the date is taken from.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: ModuleLabel(longDateLabel(now ?? DateTime.now()))),
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
      semanticLabel: 'Your strap and pairing',
      onPressed: () => context.go(Routes.pairing),
    );
  }
}
