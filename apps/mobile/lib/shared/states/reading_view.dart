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
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/shared/states/withheld_card.dart';

/// Renders a [Reading] with the honest state widgets supplied for free.
class ReadingView<T extends Object> extends StatelessWidget {
  /// Renders [reading]; [builder] draws the value when there is one.
  const ReadingView({
    required this.reading,
    required this.builder,
    this.label,
    this.caveatBuilder,
    this.excludedBuilder,
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

  /// Overrides how caveats render. Default: [CaveatNote] beneath the value.
  final Widget Function(BuildContext context, List<Disclosure> caveats)? caveatBuilder;

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
      Caveated<T>(:final value, :final caveats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          builder(context, value),
          caveatBuilder?.call(context, caveats) ?? CaveatNote(caveats: caveats),
        ],
      ),
      Withheld<T>(:final disclosure) => WithheldCard(
        disclosure: disclosure,
        label: label,
        onExplain: onExplainWithheld,
      ),
      Excluded<T>(:final exclusions) =>
        excludedBuilder?.call(context, exclusions) ?? ExcludedNote(exclusions: exclusions),
    };
  }
}
