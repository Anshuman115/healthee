/// The frame every supporting screen is drawn in — `#main` plus its header.
///
/// ```css
/// #main    { padding: 20px 16px 112px; }   /* richer.css */
/// .section { margin-top: 24px; }
/// ```
///
/// ## Why this is not `InstrumentScreen`
///
/// `shared/instrument_screen.dart` is the shell for a screen built from **two
/// data sources** — the phone's own store and `/api/today` — with a failure rule
/// per source and a reveal registry that has to outlive a lazily built list.
/// None of that applies here: a settings screen has no chart to reveal, and the
/// things it reads (the keystore, the theme, a preferences row) fail one at a
/// time and say so where they are. Borrowing that shell would put a
/// server-unreachable card at the top of the appearance screen.
///
/// The bottom padding is 112 in the prototype because a tab bar sits over it.
/// These screens are **outside** the tab shell — `core/router.dart` pushes them
/// onto the root navigator — so the bar is not there, and the reserve is
/// [bottomPadding] instead: enough that the footer clears a gesture bar, which
/// `SafeArea` then adds on top.
///
/// The header is a parameter rather than the first child so a screen cannot be
/// built without one, and so the back arrow is in one place. `router.dart`
/// records that **`push` is what draws a back control**; a screen reached that
/// way and drawing none would be a room with no door.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/shared/v02/detail_header.dart';
import 'package:healthee/shared/v02/detail_page.dart';

/// A supporting screen: the page frame, its head, and an ordered body.
class SettingsPage extends StatelessWidget {
  /// Builds the page. [children] are laid out in order with no gaps of their
  /// own — a section that wants space above it says so (`SectionGap`).
  const SettingsPage({
    required this.title,
    required this.eyebrow,
    required this.children,
    this.onBack,
    super.key,
  }) : header = null;

  /// The same frame under a head that is **not** a back arrow.
  ///
  /// Welcome opens with `.page-header` carrying the brand and an *Explore*
  /// link, because there is nothing under it to go back to. A screen reached by
  /// a `push` gets [SettingsPage.new]; this is for the one that is not.
  const SettingsPage.headed({
    required this.header,
    required this.children,
    super.key,
  }) : title = null,
       eyebrow = null,
       onBack = null;

  /// The screen's name. Null only on [SettingsPage.headed].
  final String? title;

  /// The line above it. Null only on [SettingsPage.headed].
  final String? eyebrow;

  /// Leaves the screen. Null takes `detail_page.dart`'s rule — pop when there
  /// is a stack, and otherwise go to the screen's home tab, so a settings
  /// surface restored or deep-linked into is not a dead end. `maybePop()` was
  /// here before and did **nothing at all** in that state, which is a control
  /// that looks like a way out and is not one.
  final VoidCallback? onBack;

  /// A head that is not a back arrow. Null builds a [DetailHeader].
  final Widget? header;

  /// `#main { padding-inline: 16px }`.
  static const double horizontalPadding = 16;

  /// `#main { padding-top: 20px }`.
  static const double topPadding = 20;

  /// The foot. See the library docstring on the prototype's 112.
  static const double bottomPadding = 32;

  /// The body, in order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          children: <Widget>[
            header ??
                DetailHeader(
                  title: title!,
                  eyebrow: eyebrow!,
                  onBack: onBack ?? () => leaveDetail(context),
                ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// `.section { margin-top: 24px }` — the space above a section head.
class SectionGap extends StatelessWidget {
  /// Reserves the gap.
  const SectionGap({super.key});

  /// `.section { margin-top: 24px }`.
  static const double height = 24;

  @override
  Widget build(BuildContext context) => const SizedBox(height: height);
}
