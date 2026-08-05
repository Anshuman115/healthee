/// Legacy's ten per-metric hues, as a theme extension — and the ONE canonical
/// sleep-stage mapping every sleep chart draws from.
///
/// **This file replaces `metric_hues.dart`**, which is deleted. That file held a
/// five-hue "identity tag" system built so a tag could never be mistaken for a
/// verdict: five hues, one lightness, 40° clear of `fav`/`unf`/`alert`. It was
/// internally consistent and it is **superseded**, because the legacy app — now
/// the specification — has ten hues and **deliberately reuses two of them as
/// verdicts**:
///
/// ```dart
/// // healthee-legacy/app/lib/ui/insights_screen.dart:171
/// improving ? c.green : c.cHeart
/// ```
///
/// [hrv] and [readiness] ARE the green accent and the "improving" verdict.
/// [heart] IS the "degrading" verdict and the illness flag. **Identity and
/// judgement share hues here by decision.** A future reader who notices and
/// "fixes" it will be undoing the owner's call, not a mistake — see
/// `palette.dart`'s library docstring.
///
/// ## Why still a second extension rather than fields on `HealtheeColors`
///
/// The split survives the redesign for a different reason than it was created
/// for. `HealtheeColors` is the set a widget reaches for to answer *what surface
/// am I on, what ink do I use, is this reading good or bad*. This set answers
/// *which metric is this card about*. Two questions, two extensions, and a
/// reviewer can still tell at the call site which one is being asked.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/palette.dart';

/// The ten per-metric hues for the active theme.
///
/// Field names drop legacy's `c` prefix: `cSleep` → [sleep]. Nothing else moved.
@immutable
class InstrumentHues extends ThemeExtension<InstrumentHues> {
  /// Builds a hue set. Prefer [InstrumentHues.light] / [InstrumentHues.dark].
  const InstrumentHues({
    required this.sleep,
    required this.heart,
    required this.hrv,
    required this.steps,
    required this.calories,
    required this.respiratory,
    required this.spo2,
    required this.stress,
    required this.readiness,
    required this.rem,
    required this.unstaged,
  });

  /// Legacy's `HColors.light` hues, verbatim.
  const InstrumentHues.light()
    : unstaged = LightPalette.unstaged,
      sleep = LegacyLightHues.sleep,
      heart = LegacyLightHues.heart,
      hrv = LegacyLightHues.hrv,
      steps = LegacyLightHues.steps,
      calories = LegacyLightHues.calories,
      respiratory = LegacyLightHues.respiratory,
      spo2 = LegacyLightHues.spo2,
      stress = LegacyLightHues.stress,
      readiness = LegacyLightHues.readiness,
      rem = LegacyLightHues.rem;

  /// Legacy's `HColors.dark` hues, verbatim.
  const InstrumentHues.dark()
    : unstaged = DarkPalette.unstaged,
      sleep = LegacyDarkHues.sleep,
      heart = LegacyDarkHues.heart,
      hrv = LegacyDarkHues.hrv,
      steps = LegacyDarkHues.steps,
      calories = LegacyDarkHues.calories,
      respiratory = LegacyDarkHues.respiratory,
      spo2 = LegacyDarkHues.spo2,
      stress = LegacyDarkHues.stress,
      readiness = LegacyDarkHues.readiness,
      rem = LegacyDarkHues.rem;

  /// `cSleep` — sleep, sleep debt, the sleep gauge, **and REM** on a hypnogram.
  final Color sleep;

  /// `cHeart` — heart rate, resting HR, cardio load, **awake** on a hypnogram.
  /// Also the "degrading" verdict and the illness flag.
  final Color heart;

  /// `cHrv` — HRV. The same value as the green accent and the `fav` verdict.
  final Color hrv;

  /// `cSteps` — steps and distance, **and deep sleep** on every sleep chart.
  final Color steps;

  /// `cCal` — calories, and legacy's stress card.
  final Color calories;

  /// `cResp` — respiratory rate, and legacy's overnight blood-oxygen card.
  final Color respiratory;

  /// `cSpo2` — **light/core sleep** on every sleep chart, SpO₂ vitals, zone 1.
  final Color spo2;

  /// `cStress` — skin temperature. Legacy's stress card wears [calories].
  final Color stress;

  /// `cReady` — VO₂max, biological age, regularity, training load. The same
  /// value as the green accent.
  final Color readiness;

  /// `cRem` — defined by legacy, drawn by no legacy screen. See `palette.dart`.
  final Color rem;

  /// **Not legacy's.** The chroma-free grey an unrecognised stage code is drawn
  /// in. See [sleepStage] and `LightPalette.unstaged`.
  final Color unstaged;

  /// **The canonical sleep-stage colour. One mapping, every sleep chart.**
  ///
  /// Legacy's four, to the hex (`HColors.sleepStage`):
  ///
  /// ```text
  ///   deep          → cSteps     amber
  ///   core / light  → cSpo2      blue
  ///   rem           → cSleep     purple
  ///   awake         → cHeart     red
  ///   anything else → unstaged   grey        ← NOT legacy
  /// ```
  ///
  /// `core` is the server's word for what the strap calls `light`; they are one
  /// stage under two vocabularies, so they are one colour.
  ///
  /// ## The fifth row is the one departure, and it is not a design change
  ///
  /// Legacy defaults an unrecognised code to `cSpo2` (`theme.dart:36` and
  /// `instrument_charts.dart:403` both do) — **it draws a byte nobody has
  /// decoded as light sleep.** That is not a colour choice, it is a claim: a
  /// specific named stage, asserted about a measurement we could not read, and
  /// indistinguishable on screen from a real one. Silently mislabelling a
  /// measurement is the failure this app exists to prevent, so the fifth row is
  /// a grey and [sleepStageLabel] already answers "Unrecognised" beside it.
  ///
  /// The four legacy rows are untouched. A screen showing only recognised stages
  /// — which is every screen, on every payload the strap has ever sent — is
  /// pixel-identical to legacy.
  Color sleepStage(String stage) => switch (stage) {
    'deep' => steps,
    'core' || 'light' => spo2,
    'rem' => sleep,
    'awake' => heart,
    _ => unstaged,
  };

  /// Whether [stage] is a code this app can name. The predicate the charts and
  /// their legends share, so a grey band and its key cannot disagree.
  static bool isRecognised(String stage) =>
      const <String>{'deep', 'core', 'light', 'rem', 'awake'}.contains(stage);

  @override
  InstrumentHues copyWith({
    Color? sleep,
    Color? heart,
    Color? hrv,
    Color? steps,
    Color? calories,
    Color? respiratory,
    Color? spo2,
    Color? stress,
    Color? readiness,
    Color? rem,
    Color? unstaged,
  }) => InstrumentHues(
    unstaged: unstaged ?? this.unstaged,
    sleep: sleep ?? this.sleep,
    heart: heart ?? this.heart,
    hrv: hrv ?? this.hrv,
    steps: steps ?? this.steps,
    calories: calories ?? this.calories,
    respiratory: respiratory ?? this.respiratory,
    spo2: spo2 ?? this.spo2,
    stress: stress ?? this.stress,
    readiness: readiness ?? this.readiness,
    rem: rem ?? this.rem,
  );

  @override
  InstrumentHues lerp(ThemeExtension<InstrumentHues>? other, double t) {
    if (other is! InstrumentHues) {
      return this;
    }
    return InstrumentHues(
      unstaged: Color.lerp(unstaged, other.unstaged, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      hrv: Color.lerp(hrv, other.hrv, t)!,
      steps: Color.lerp(steps, other.steps, t)!,
      calories: Color.lerp(calories, other.calories, t)!,
      respiratory: Color.lerp(respiratory, other.respiratory, t)!,
      spo2: Color.lerp(spo2, other.spo2, t)!,
      stress: Color.lerp(stress, other.stress, t)!,
      readiness: Color.lerp(readiness, other.readiness, t)!,
      rem: Color.lerp(rem, other.rem, t)!,
    );
  }

  /// Every hue, in declaration order. **Add a new hue here too** — this backs
  /// equality, and Flutter compares theme extensions to decide whether a theme
  /// change needs a rebuild.
  List<Color> get _hues => <Color>[
    sleep, heart, hrv, steps, calories,
    respiratory, spo2, stress, readiness, rem,
    unstaged,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! InstrumentHues) {
      return false;
    }
    final mine = _hues;
    final theirs = other._hues;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_hues);
}

/// Reaches the hue set from a widget: `context.hues.heart`.
extension InstrumentHuesOf on BuildContext {
  /// The active theme's per-metric hues.
  ///
  /// Throws when the theme was built without the extension, which is the right
  /// behaviour: a silent fallback would let a screen render in colours nobody
  /// chose and look almost right.
  InstrumentHues get hues => Theme.of(this).extension<InstrumentHues>()!;
}
