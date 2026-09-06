/// The cascade half of the tone system — `richer.css`'s `[data-tone]` selector.
///
/// A [ToneScope] is what a `data-tone` attribute is: it changes nothing about
/// itself and everything about what is drawn inside it. Contents read
/// [ToneOf.family] and [ToneOf.familySoft] from their own `BuildContext`, so a
/// panel that changes tone repaints its line, its dots, its icon tile and its
/// progress fill together and by construction.
///
/// **There is no `Color` parameter anywhere in this system, and that is the
/// design.** A widget that accepted one could be handed a colour that disagrees
/// with the card it is sitting in, and nothing would catch it — which is exactly
/// how `metric_hue.dart`'s docstring records legacy drawing cardio load red on
/// one screen and green on another.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tone.dart';

/// Declares the tone for everything beneath it.
class ToneScope extends InheritedWidget {
  /// Wraps [child] in [tone].
  const ToneScope({required this.tone, required super.child, super.key});

  /// The family every descendant resolves.
  final Tone tone;

  /// The nearest declared tone, or [Tone.fitness] when there is none.
  ///
  /// The fallback is `richer.css` `:root { --family: var(--fitness) }` — not a
  /// defensive default. Content outside any toned container is green in the
  /// prototype, so it is green here.
  static Tone of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToneScope>()?.tone ??
      Tone.fitness;

  @override
  bool updateShouldNotify(ToneScope oldWidget) => oldWidget.tone != tone;
}

/// Reads the cascade: `context.family`, the way CSS reads `var(--family)`.
extension ToneOf on BuildContext {
  /// The declared tone, or [Tone.fitness].
  Tone get tone => ToneScope.of(this);

  /// `var(--family)` — the resolved identity colour at this point in the tree.
  Color get family => tone.family(Theme.of(this).extension<InstrumentHues>()!);

  /// `var(--family-soft)` — its fill.
  Color get familySoft =>
      tone.familySoft(Theme.of(this).extension<InstrumentHues>()!);
}
