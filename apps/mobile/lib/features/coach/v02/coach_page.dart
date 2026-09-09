/// The coach's own scaffold — a conversation, not a document.
///
/// Every other detail screen in this app is `DetailPage`: a `ListView` with a
/// head on top and everything else scrolling under it. That is right for a
/// screen you read. It is wrong for one you talk to, and the difference showed
/// up as two concrete faults on the device:
///
/// * **the input scrolled.** In a `ListView` the composer is just another child,
///   so where it sits depends on how much is above it. With the opening block it
///   was off the bottom of the phone; with the block removed it floated at the
///   top of an empty screen. Neither is a place to put the control the screen
///   exists for;
/// * **there was nowhere for the screen's own actions to live.** `DetailHead`
///   takes a title, an eyebrow and a back control, and a conversation needs more
///   than that — starting a new one is an action ON the thread, not a link to
///   somewhere else.
///
/// So the thread scrolls and the composer does not. This is the shape the legacy
/// coach uses (a header row of actions, the conversation, a pinned input) and the
/// shape of every messaging surface, for the same reason in each: the thing you
/// are about to say stays put while the thing you have already said moves.
///
/// ## `bottom: false` on the SafeArea is deliberate, and inverted here
///
/// `DetailPage` sets it because its content scrolls under the system bar. This
/// page pins a control there, so it must respect the inset or the send control
/// lands under the gesture bar — the one place a mis-set inset is not cosmetic.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/shared/v02/detail_page.dart';
import 'package:healthee/shared/v02/screen_head.dart';

/// A scrolling conversation over a pinned composer.
class CoachPage extends StatelessWidget {
  /// [actions] sit at the trailing edge of the head. [footer] is pinned.
  const CoachPage({
    required this.title,
    required this.eyebrow,
    required this.children,
    required this.footer,
    this.actions = const <Widget>[],
    super.key,
  });

  /// The page's own padding, matching `DetailPage`'s so the coach does not read
  /// as a differently-margined screen.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(
    Insets.lg,
    Insets.lg,
    Insets.lg,
    Insets.lg,
  );

  /// `.page-title`.
  final String title;

  /// The line above it.
  final String eyebrow;

  /// The conversation, and whatever stands in for it while it is empty.
  final List<Widget> children;

  /// The composer. Pinned: it does not scroll with [children].
  final Widget footer;

  /// Controls on the thread itself — a new conversation, its history.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final bool stacked = Navigator.of(context).canPop();
    final bool canLeave = stacked || GoRouter.maybeOf(context) != null;
    return PopScope<Object?>(
      canPop: stacked,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          leaveDetail(context);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.lg,
                  Insets.lg,
                  0,
                ),
                // The SHARED head, not a hand-rolled row. The first version of
                // this page built a raw `IconButton` beside a `Column`, which put
                // a 48 pt Material target with its own padding next to the 44 pt
                // outdented control every other screen uses — so the coach's head
                // sat a few pixels off from the whole rest of the app, which is
                // exactly how it read.
                child: DetailHead(
                  title: title,
                  eyebrow: eyebrow,
                  onBack: canLeave ? () => leaveDetail(context) : null,
                  actions: actions,
                ),
              ),
              Expanded(
                child: ListView(padding: padding, children: children),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  0,
                  Insets.lg,
                  Insets.lg,
                ),
                child: footer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
