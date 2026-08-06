/// The one way a modal sheet is opened in this app, and the one way its foot is
/// padded.
///
/// ## The defect this exists to make unrepeatable
///
/// The owner: *"the info sheet comes beyond the navbar"*. `showModalBottomSheet`
/// defaults to `useRootNavigator: false`, which resolves the **nearest**
/// `Navigator` — and inside `StatefulShellRoute.indexedStack` that is the current
/// tab's own branch navigator, which lives inside `Scaffold.body`. So the sheet
/// was laid out in one tab's content box:
///
/// ```text
///   measured, 360×780 phone, gesture inset 24:
///     branch navigator   sheet 0 →  683      the bar's top edge
///     root navigator     sheet 0 →  780      the screen's bottom edge
/// ```
///
/// Three things follow from the first row, and only the third is obvious:
///
///   * the sheet **ends flush against an opaque bar** rather than the screen
///     edge, so its last line of prose runs straight into the tab labels with no
///     gap and nothing to say the rest scrolls;
///   * the **scrim never covers the bar**, so the bar stays lit and tappable
///     under a modal — a tab press behind an open sheet switches the screen
///     underneath it;
///   * the sheet cannot use the room it needs. The longest explainer
///     (`sleep_consistency`) wants 1,844 px and got a 637 px viewport instead of
///     734.
///
/// A modal is over the **app**, not over one tab's content. That is what
/// [showAppSheet] fixes, and it fixes it in one place because the sibling sheet
/// (the coach) had exactly the same presentation — *"fixing one instance of a
/// layering bug while its siblings keep it is how this reappears next week."*
/// `test/features/sheet_layering_test.dart` scans `lib/` and fails the build if
/// a third sheet is ever opened any other way.
///
/// ## Covering the bar means owning the inset it was covering
///
/// Under the old presentation the sheet never had to think about the gesture
/// inset: the bar sat below it and `AppTabBar`'s own `SafeArea` absorbed it. A
/// sheet that paints over the bar inherits that job, and `MediaQuery` inside a
/// root-navigator route reports the real inset again (it reads
/// `EdgeInsets.zero` inside `Scaffold.body`, because the `Scaffold` had already
/// spent it on the bar). So every sheet's foot ends at [sheetBottomInset], and
/// that is a function rather than a convention for the same reason this file is
/// a function rather than a convention.
library;

import 'package:flutter/material.dart';

/// Opens [builder] as a modal sheet **over the whole app**.
///
/// `useRootNavigator: true` is not optional and is deliberately not a parameter:
/// the branch-navigator presentation is the defect, and a flag would let it back
/// in. `useSafeArea: true` keeps a full-height sheet's grab handle out from under
/// the status bar — the other end of the same problem.
///
/// The sheet is transparent and scroll-controlled because every sheet in this
/// app draws its own container and decides its own height; a Material surface
/// underneath would put a second background behind the rounded one.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// How much room a sheet's last line must leave beneath itself.
///
/// `viewInsets.bottom` is the keyboard and `padding.bottom` is what is left of
/// the gesture inset after the keyboard has taken its share — so the two add
/// rather than compete, and the sum is correct with the keyboard up (inset, no
/// gesture bar visible) and down (no inset, gesture bar visible).
///
/// It is deliberately **not** `viewPadding.bottom`: that one ignores the
/// keyboard, so a sheet with an input would hold a gesture-bar gap open beneath
/// a keyboard that is already covering it.
double sheetBottomInset(BuildContext context) {
  final media = MediaQuery.of(context);
  return media.viewInsets.bottom + media.padding.bottom;
}
