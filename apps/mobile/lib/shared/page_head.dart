/// A screen's opening row — an eyebrow, a display-size title, the theme toggle.
///
/// **Ported from** `design_reference/project/hh/ui.jsx`'s `PageHead`, which every
/// legacy screen except Today begins with: a small tracked eyebrow, a 38 px title
/// under it, and the round theme toggle on the right. Today has its own opening
/// (a greeting rather than a noun) and uses [ThemeToggleButton] directly.
///
/// The circular control is shared because both headers draw it and Standards §1
/// treats the second occurrence as the extraction point. It was defined privately
/// inside `today_header.dart` until Sleep, Activity, Coach and Diagnostics needed
/// the same button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/theme_controller.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/instrument_module.dart';

/// The eyebrow-over-title header the non-Today screens open with.
class PageHead extends StatelessWidget {
  /// [eyebrow] is the small line above [title].
  const PageHead({required this.eyebrow, required this.title, super.key});

  /// `LAST NIGHT · 23:40 → 06:00` — context for the title.
  final String eyebrow;

  /// The screen's name, at display size.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModuleLabel(eyebrow),
              const SizedBox(height: Insets.sm),
              Text(title, style: Theme.of(context).textTheme.displayMedium),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        const ThemeToggleButton(),
      ],
    );
  }
}

/// A circular hairline button — legacy's header control.
class CircleIconButton extends StatelessWidget {
  /// [semanticLabel] is what a screen reader announces; the icon is decoration.
  const CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// The glyph inside the circle.
  final IconData icon;

  /// What the button does, in words.
  final String semanticLabel;

  /// Tapped.
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
///
/// `ThemeController` defaults to `ThemeMode.system`, so the first tap has to
/// decide what it is toggling FROM. It reads the brightness actually being
/// rendered and asks for the opposite, which is what the owner means by tapping
/// it — not "stop following the system" in the abstract.
class ThemeToggleButton extends ConsumerWidget {
  /// The round sun/moon control in a screen's header.
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CircleIconButton(
      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      semanticLabel: dark ? 'Switch to the light theme' : 'Switch to the dark theme',
      onPressed: () => ref
          .read(themeControllerProvider.notifier)
          .set(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
