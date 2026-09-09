/// How a caveat reaches the card that owns the number.
///
/// ## The defect, 2026-08-06
///
/// Owner, on the installed build: *"the caveat is sitting and its difficutlt to
/// understand which caveat is that pointing to"*.
///
/// `ReadingView` renders a `Caveated` value's signpost as a **sibling beneath
/// whatever the builder returned**. On Today the builder returns a whole card,
/// so the signpost landed in the gutter *between* two cards — closer to the card
/// below it than to the one it qualifies once the gap was even. A disclosure
/// attached to the wrong number is not a weaker disclosure; it is a
/// **misattributed** one, and it can read as qualifying a figure that is in fact
/// unqualified. That is a new false claim, produced entirely by layout.
///
/// ## The fix: the caveats travel INTO the card
///
/// [CaveatScope] is what `ReadingView` hands down instead of drawing. The card's
/// own [InstrumentModule] reads it and renders the signpost inside its own
/// padding, within the card's bounds, under the number it is about.
///
/// **Two things keep it from becoming an invisible disclosure**, which is the
/// failure this whole layer exists to prevent and is worse than the orphan:
///
///   * the carrier is opt-in per call site ([CaveatCarrier]), and the default is
///     still the note beneath. A screen that has not been looked at keeps the
///     old, ugly, *visible* behaviour rather than silently losing the sentence.
///   * `test/features/caveat_attribution_test.dart` walks the real screen and
///     fails if a caveat carrier is laid out outside the card it belongs to, or
///     if a caveated reading has no carrier at all.
///
/// A module that claims a scope **shadows it for its own subtree** with an empty
/// one, so a module nested inside another cannot render the same disclosure a
/// second time.
library;

import 'package:flutter/widgets.dart';
import 'package:healthee/data/honesty/disclosure.dart';

/// Where a `Caveated` value's signpost is drawn.
enum CaveatCarrier {
  /// Beneath whatever the builder returned. The default, and correct when the
  /// builder returns loose content rather than a card.
  beneath,

  /// Inside the card the builder returns — see the library docstring. The card
  /// must contain an `InstrumentModule`, which is what claims the scope.
  insideCard,

  /// **The card routes them itself, so this draws nothing.**
  ///
  /// The only carrier that renders no sentence, and therefore the only one that
  /// can lose a disclosure — so it exists as its own named value rather than as
  /// a null or a flag. A card passing this is claiming to have put the caveats
  /// somewhere a reader can reach, which today means its ⓘ
  /// (`MetricDetail.disclosures`).
  ///
  /// Do not reach for it to quieten a card. `beneath` and `insideCard` both
  /// SHOW the sentence; this one moves it, and moving it is only honest if it
  /// arrives somewhere.
  routedByCard,
}

/// Carries a caveated value's disclosures down to the card that shows it.
class CaveatScope extends InheritedWidget {
  /// [caveats] may be empty, which is how a module shadows an outer scope.
  const CaveatScope({
    required this.caveats,
    required super.child,
    this.label,
    super.key,
  });

  /// What tilts the value the card below is about.
  final List<Disclosure> caveats;

  /// The metric's name, for the sheet's subtitle.
  final String? label;

  /// The nearest enclosing scope, or null.
  static CaveatScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CaveatScope>();

  @override
  bool updateShouldNotify(CaveatScope old) =>
      old.caveats != caveats || old.label != label;
}
