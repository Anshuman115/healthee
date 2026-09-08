/// **The tone.** v02's central idea, ported from `richer.css` lines 37-50.
///
/// In the prototype a container carries `data-tone="sleep"`, which sets one
/// custom property — `--family` — and everything inside then resolves it: the
/// line stroke, the dot, the bar fill, the area gradient's stops, the icon
/// tile's foreground and background, the progress fill. Nothing is passed a
/// colour; the colour cascades.
///
/// The Flutter equivalent is this enum plus `tone_scope.dart`. A card declares
/// its tone **once**; its contents read `context.family` / `context.familySoft`
/// and never take a `Color` parameter. That is the whole point: passing the hue
/// down is how one card ends up two colours, and it is what
/// `test/theme/tone_cascade_test.dart` exists to prevent.
///
/// ## Nine names, six families — deliberately
///
/// `richer.css` gives three families two tone names each: `fitness`/`recovery`,
/// `heart`/`load`, `movement`/`activity`. They are aliases in the CSS and they
/// are aliases here. Keeping both means a card can say what it is *about*
/// (`Tone.load`) rather than what colour it wants (`Tone.heart`), which is the
/// difference between a name that survives a palette change and one that does
/// not.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';

/// A card's tone: which category family everything inside it resolves to.
///
/// The default is [Tone.fitness] — `richer.css` `:root` sets
/// `--family: var(--fitness)`, so content outside any `data-tone` is green.
enum Tone {
  /// Recovery, HRV, VO₂max. The `:root` default, and the app's accent.
  fitness,

  /// Alias of [fitness]. `[data-tone='recovery']`.
  recovery,

  /// Sleep, sleep debt, sleep timing.
  sleep,

  /// Heart rate, resting HR.
  heart,

  /// Alias of [heart]. Cardio load. `[data-tone='load']`.
  load,

  /// Steps, distance, calories, energy.
  movement,

  /// Alias of [movement]. `[data-tone='activity']`.
  activity,

  /// Respiratory rate, blood oxygen.
  oxygen,

  /// Stress, skin temperature.
  stress,
}

/// Resolves a [Tone] against the active theme's [InstrumentHues].
extension ToneFamily on Tone {
  /// `--family` — the line, the dot, the icon, the number that carries identity.
  Color family(InstrumentHues hues) => switch (this) {
    Tone.fitness || Tone.recovery => hues.fitness,
    Tone.sleep => hues.sleep,
    Tone.heart || Tone.load => hues.heart,
    Tone.movement || Tone.activity => hues.movement,
    Tone.oxygen => hues.oxygen,
    Tone.stress => hues.stress,
  };

  /// `--family-soft` — the fill behind [family]: a tile's ground, an icon tile.
  Color familySoft(InstrumentHues hues) => switch (this) {
    Tone.fitness || Tone.recovery => hues.fitnessSoft,
    Tone.sleep => hues.sleepSoft,
    Tone.heart || Tone.load => hues.heartSoft,
    Tone.movement || Tone.activity => hues.movementSoft,
    Tone.oxygen => hues.oxygenSoft,
    Tone.stress => hues.stressSoft,
  };

  /// The family this tone is an alias of, so a test can enumerate the six.
  Tone get canonical => switch (this) {
    Tone.recovery => Tone.fitness,
    Tone.load => Tone.heart,
    Tone.activity => Tone.movement,
    _ => this,
  };
}

/// The six distinct families, in `richer.css` declaration order. An alias is
/// **not** here; [ToneFamily.canonical] maps onto it.
const List<Tone> kToneFamilies = <Tone>[
  Tone.fitness,
  Tone.sleep,
  Tone.heart,
  Tone.movement,
  Tone.oxygen,
  Tone.stress,
];
