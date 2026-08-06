/// One entry in a screen's section list: a widget and the gap that follows it.
///
/// The gap belongs to the section rather than to the list because the screens
/// have two rhythms and only one of them is padding. Legacy's modules sit 10 px
/// apart inside a group and its section breaks are more than twice that; a list
/// that padded everything to one gap would read as a pile of unrelated cards,
/// which is exactly what the screen this rebuild replaced looked like.
///
/// Extracted out of `features/today/` when Sleep, Activity, Coach and
/// Diagnostics started building the same kind of list (Standards §1: second
/// occurrence = extract). A section type living in one feature would have been a
/// feature reaching sideways into another, which §1 also forbids.
library;

import 'package:flutter/widgets.dart';

/// The gap under a section — **the only place a screen's vertical rhythm lives**.
///
/// ## Owner-directed departure from the verbatim-legacy rule, 2026-08-06
///
/// *"give some space between cards it looks too cramped in between"*. Legacy's
/// gaps were ported literally and they are tight: 10 px between sibling cards,
/// 14 under a chart, 16 before a related block, 24 before a section heading. All
/// four grew, and they grew **as a ladder**, because the rungs are what carry the
/// grouping — a screen that padded everything to one gap would read as a pile of
/// unrelated cards, which is what this rebuild replaced. The relationship legacy
/// encodes is preserved: a section break is still comfortably wider than a gap
/// between siblings (34 against 18, where legacy had 24 against 10).
///
/// This grew by the same repair as the caveat carrier and is not a coincidence:
/// a wider gutter is only an improvement once the gutter is EMPTY. While a
/// caveat note floated between two cards, widening the gap would have made the
/// misattribution worse rather than better. See `caveat_scope.dart`.
///
/// Call sites name a rung. A literal at a call site is how a ladder stops being
/// one, so `test/features/page_spacing_test.dart` fails the build on a screen
/// that writes its own number.
abstract final class PageSpacing {
  /// Between two cards in the same section. Legacy's 10.
  static const double card = 18;

  /// Between a card and the one it is directly about — a chart and its legend,
  /// a pair that reads as one block. Legacy's 14.
  static const double related = 22;

  /// Between two groups inside one section, where there is no heading to carry
  /// the break. Legacy's 16.
  static const double group = 26;

  /// Under the last card of a section, before the next heading. Legacy's 24.
  static const double section = 34;
}

/// A section [child] followed by [gap] of space.
@immutable
class PageSection {
  /// Builds one entry of a screen's list.
  const PageSection(this.child, {this.gap = PageSpacing.card});

  /// What to draw.
  final Widget child;

  /// The space under it.
  final double gap;
}
