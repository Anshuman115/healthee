/// The coach button — on Today, and nowhere else.
///
/// **Ported from** `app/lib/main.dart:399`: `if (_tab == 0) return
/// CoachFab(onTap: _openCoach);`. The legacy shell shows it on Today only, and
/// `docs/APP_DESIGN.md` §2 describes the same thing — a FAB on Today rather than
/// a sixth tab.
///
/// It is on Today because that is the screen the question is *about*: "why is my
/// recovery low today" is asked with today's numbers in front of you. On Sleep or
/// Activity the same button would be a second, quieter entrance to one surface,
/// and `shared/app_shell.dart` shows it for `currentIndex == 0` alone.
///
/// Legacy also draws a record-workout FAB on Activity. That is a different
/// feature and this app does not have it; nothing here is shaped to make it easy
/// to bolt on, because a control that starts a recording nothing can stop would be
/// worse than no control.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:solar_icons/solar_icons.dart';

/// The floating control that opens the coach sheet.
class CoachFab extends StatelessWidget {
  /// [onTap] opens the sheet.
  const CoachFab({required this.onTap, super.key});

  /// Opens the coach.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
      tooltip: 'Ask your coach',
      child: const Icon(SolarIconsOutline.chatRoundDots),
    );
  }
}
