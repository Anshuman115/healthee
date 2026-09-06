/// [ReadingView] — renders a [Reading] so that forgetting a state is impossible.
///
/// A screen could switch on the union itself; the compiler would make it handle
/// all four. This widget exists because "handle all four" and "handle all four
/// *well*" are different bars, and the second one is a design decision that should
/// be made once. Here, a caller supplies only what is specific to their metric —
/// how a value looks — and the three honest states come from the shared widgets
/// automatically:
///
/// ```dart
/// ReadingView<Vo2max>(
///   reading: snapshot.vo2max,
///   label: 'VO₂max',
///   builder: (context, vo2max) => Vo2maxHero(vo2max),
/// )
/// ```
///
/// The caveats of a [Caveated] are rendered **under the caller's widget without
/// being asked for**. That is the whole reason this is a widget and not a helper
/// function: a caller who treats [Caveated] as "same as Present" gets the
/// disclosure anyway, and dropping it takes a deliberate `caveatBuilder`
/// override rather than an oversight.
///
/// What that disclosure LOOKS like changed on 2026-08-06: it was every message in
/// full, inline, which put ~2,780 characters of server prose under Today's
/// biological-age card. It is now [CaveatNote]'s one-line signpost, which names
/// the state, counts the disclosures and opens them in a sheet. The rule is
/// unchanged and is the one that matters — a caveated value discloses, unasked.
///
/// **Where it is drawn changed later the same day**, on the owner's second
/// report: a signpost rendered as a sibling *beneath* a whole card lands in the
/// gutter between two cards and stops naming which number it is about.
/// [caveatCarrier] is the answer — see `caveat_scope.dart`, which carries the
/// argument and the guard.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/states/withheld_card.dart';

/// Renders a [Reading] with the honest state widgets supplied for free.
class ReadingView<T extends Object> extends StatelessWidget {
  /// Renders [reading]; [builder] draws the value when there is one.
  const ReadingView({
    required this.reading,
    required this.builder,
    this.label,
    this.caveatCarrier = CaveatCarrier.beneath,
    this.caveatBuilder,
    this.excludedBuilder,
    this.withheldBuilder,
    this.onExplainWithheld,
    super.key,
  });

  /// The value and its honesty state.
  final Reading<T> reading;

  /// The metric's owner-facing name, passed to the withheld card so a refusal is
  /// self-describing in a list.
  final String? label;

  /// Draws the value. Called for [Present] and [Caveated] alike — a caveated
  /// value is a real value and is meant to be shown.
  final Widget Function(BuildContext context, T value) builder;

  /// Where a [Caveated] value's signpost is drawn.
  ///
  /// [CaveatCarrier.beneath] — the default and the old behaviour — is right when
  /// [builder] returns loose content. Pass [CaveatCarrier.insideCard] when it
  /// returns a CARD: the disclosures then travel down a [CaveatScope] and the
  /// card's own `InstrumentModule` draws them within its bounds, instead of the
  /// note floating in the gap between two cards. See `caveat_scope.dart`.
  final CaveatCarrier caveatCarrier;

  /// Overrides how caveats render. Default: [CaveatNote] beneath the value.
  ///
  /// Ignored under [CaveatCarrier.insideCard], where the card is the carrier.
  final Widget Function(BuildContext context, List<Disclosure> caveats)? caveatBuilder;

  /// Overrides how a refusal renders. Default: [WithheldCard].
  ///
  /// **It cannot be overridden into silence**, only into a different shape: the
  /// builder is called with the disclosure and whatever it returns is what the
  /// screen shows. v02 passes `WithheldPanel`, which is the same contract — the
  /// metric's name, a hole, and the reason — in the new geometry.
  final Widget Function(BuildContext context, Disclosure disclosure)?
  withheldBuilder;

  /// Overrides how a total exclusion renders. Default: [ExcludedNote].
  final Widget Function(BuildContext context, List<Disclosure> exclusions)? excludedBuilder;

  /// Opens the longer explanation behind a [Withheld] value, when one exists.
  ///
  /// Passed straight to [WithheldCard]. Deliberately NOT offered for [Excluded]:
  /// there is nothing to restore, so there is nothing to open about restoring it.
  final VoidCallback? onExplainWithheld;

  @override
  Widget build(BuildContext context) {
    // The exhaustive switch. Adding a fifth Reading case breaks this line, which
    // is exactly the intended blast radius: one compile error in the one place
    // that decides what a new honesty state looks like.
    return switch (reading) {
      Present<T>(:final value) => builder(context, value),
      Caveated<T>(:final value, :final caveats) =>
        caveatCarrier == CaveatCarrier.insideCard
        ? CaveatScope(
            caveats: caveats,
            label: label,
            child: builder(context, value),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              builder(context, value),
              caveatBuilder?.call(context, caveats) ??
                  CaveatNote(caveats: caveats, label: label),
            ],
          ),
      Withheld<T>(:final disclosure) =>
        withheldBuilder?.call(context, disclosure) ??
            WithheldCard(
              disclosure: disclosure,
              label: label,
              onExplain: onExplainWithheld,
            ),
      Excluded<T>(:final exclusions) =>
        excludedBuilder?.call(context, exclusions) ?? ExcludedNote(exclusions: exclusions),
    };
  }
}
