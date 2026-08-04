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
/// **The toggle sets an explicit mode.** `ThemeController` defaults to
/// `ThemeMode.system`, so the first tap has to decide what it is toggling FROM.
/// It reads the brightness actually being rendered and asks for the opposite,
/// which is what the owner means by tapping it — not "stop following the system"
/// in the abstract.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/features/today/widgets/instrument_module.dart';

/// Today's date, and the two controls that sit beside it.
class TodayHeader extends ConsumerWidget {
  /// [now] is injected so the date does not read the wall clock in a test.
  const TodayHeader({this.now, super.key});

  /// The instant the date is taken from.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(child: ModuleLabel(longDateLabel(now ?? DateTime.now()))),
        const _ThemeToggle(),
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

/// A circular button in the hairline style legacy used for both header controls.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.line, width: hairline),
          ),
          child: Icon(icon, size: 17, color: colors.ink2),
        ),
      ),
    );
  }
}

/// Light ⇄ dark, from whatever is actually on screen.
class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _CircleButton(
      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      semanticLabel: dark ? 'Switch to the light theme' : 'Switch to the dark theme',
      onPressed: () => ref
          .read(themeControllerProvider.notifier)
          .set(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

/// The way to the strap this app is paired to. See the library docstring.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context) {
    return _CircleButton(
      icon: Icons.person_outline,
      semanticLabel: 'Your strap and pairing',
      onPressed: () => context.go(Routes.pairing),
    );
  }
}
