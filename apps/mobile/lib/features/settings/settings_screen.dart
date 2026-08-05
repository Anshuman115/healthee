/// Settings — the surfaces about the app, gathered where they can be found.
///
/// Nothing here is new behaviour. Every row on this screen already existed and
/// was reachable from somewhere odd, or not at all: the theme only from a round
/// button in a screen header, the server session only from inside the pairing
/// flow, diagnostics only from that same flow, and the font licence only from the
/// repository. Standards §1's "one responsibility" applied to navigation —
/// *"where do I change how this app behaves"* had four answers and none of them
/// was a screen.
///
/// ## Two rules this screen is built to keep
///
/// **One source of truth per setting, never a second control with its own
/// state.** The theme row reads and writes `themeControllerProvider`, which is
/// the same object the header's `ThemeToggleButton` writes, so the two agree by
/// construction rather than by being kept in step. A `bool _dark` in this
/// screen's `State` would have been a second copy of a fact the app already has.
///
/// **No row that controls nothing.** Every entry either changes something now or
/// opens a screen that does. Sign-out and unpair are *routed to* rather than
/// re-implemented — `features/signin/` owns one and `features/pairing/` owns the
/// other, and Standards §3 forbids a feature reaching into another feature's
/// code. Two sign-out buttons would be two places for the keystore write to
/// diverge; one button and one link is the same affordance with one
/// implementation.
///
/// ## Where it sits
///
/// Outside the tab shell (`core/router.dart`), reached from the Today header's
/// avatar — the entry point that already existed. The avatar used to open the
/// pairing screen directly, which is why the pairing screen had grown a "Your
/// server" card and an "Open diagnostics" card that are not about pairing. Those
/// rows are now here, where they were always trying to be, and the pairing screen
/// keeps the ones that are its own.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/features/settings/widgets/about_setting.dart';
import 'package:healthee/features/settings/widgets/diagnostics_setting.dart';
import 'package:healthee/features/settings/widgets/server_setting.dart';
import 'package:healthee/features/settings/widgets/strap_setting.dart';
import 'package:healthee/features/settings/widgets/theme_setting.dart';

/// Appearance, the server, the strap, the instruments and the notices.
class SettingsScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const SettingsScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          const ThemeSetting(),
          const SizedBox(height: Insets.md),
          const ServerSetting(),
          const SizedBox(height: Insets.md),
          StrapSetting(now: now),
          const SizedBox(height: Insets.md),
          const DiagnosticsSetting(),
          const SizedBox(height: Insets.md),
          const AboutSetting(),
        ],
      ),
    );
  }
}
