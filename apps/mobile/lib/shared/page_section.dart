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
import 'package:healthee/core/theme/dimensions.dart';

/// The gap under a section.
abstract final class PageSpacing {
  /// Between two cards in the same section.
  static const double card = Insets.md;

  /// Under the last card of a section, before the next heading.
  static const double section = Insets.xl;
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
