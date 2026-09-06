/// v02's six category families as a theme extension, plus the ONE canonical
/// sleep-stage mapping every stage plot and legend draws from.
///
/// **This replaced legacy's ten per-metric hues on 2026-09-06.** The prototype in
/// `design/mobile-preview/` assigns meaning to six colours and no more, so the
/// ten collapsed: `hrv`/`readiness` → [fitness], `steps`/`calories` →
/// [movement], `respiratory`/`spo2` → [oxygen], `rem` → [sleep]. `palette.dart`
/// records the collapse; `metric_hue.dart` records which metric lands where.
///
/// **Nothing should read these fields by name.** `tone.dart` is the reader: a
/// card declares a [Tone] and its contents resolve `context.family`. The fields
/// are public only because a `ThemeExtension` cannot hide them.
///
/// ## Why still a second extension rather than fields on `HealtheeColors`
///
/// `HealtheeColors` answers *what surface am I on, what ink do I use, is this
/// reading good or bad*. This one answers *which category is this card about*.
/// Two questions, two extensions, and a reviewer can tell at the call site which
/// one is being asked.
///
/// ## The stage ramp is NOT v02's, and that is a decision with a number on it
///
/// `richer.css` ships four stage colours — `#5E38C1 #89A9F1 #C96BCC #EDA253`
/// light — that **fail the accessibility gate this app already has**. Measured:
/// light-vs-REM is 1.39:1 and light-vs-awake is 1.10:1 against a floor of
/// `kStagePairFloor` (1.5), and in the light theme `light` and `awake` reach only
/// 2.33:1 and 2.12:1 on a white card against `kStageSurfaceFloor` (3.0). That is
/// the same class of defect the ramp in `sleep_stage_palette.dart` was authored
/// to repair, and the owner reported it on a shipped build.
///
/// So [stageDeep] and friends keep the repaired ramp. v02's four are recorded in
/// `sleep_stage_palette.dart` as `V02StagePrototype`, and
/// `test/theme/stage_contrast_test.dart` proves the gate rejects them — because a
/// rejected design that is not written down is a design that comes back.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/palette.dart';
import 'package:healthee/core/theme/sleep_stage_palette.dart';

/// v02's category families, and the sleep-stage ramp, for one theme.
@immutable
class InstrumentHues extends ThemeExtension<InstrumentHues> {
  /// Builds a hue set. Prefer [InstrumentHues.light] / [InstrumentHues.dark].
  const InstrumentHues({
    required this.fitness, required this.fitnessSoft,
    required this.sleep, required this.sleepSoft,
    required this.heart, required this.heartSoft,
    required this.movement, required this.movementSoft,
    required this.oxygen, required this.oxygenSoft,
    required this.stress, required this.stressSoft,
    required this.stageDeep, required this.stageLight,
    required this.stageRem, required this.stageAwake,
    required this.unstaged,
  });

  /// v02's families, light, with the repaired stage ramp.
  const InstrumentHues.light()
    : fitness = LightFamilies.fitness,
      fitnessSoft = LightFamilies.fitnessSoft,
      sleep = LightFamilies.sleep,
      sleepSoft = LightFamilies.sleepSoft,
      heart = LightFamilies.heart,
      heartSoft = LightFamilies.heartSoft,
      movement = LightFamilies.movement,
      movementSoft = LightFamilies.movementSoft,
      oxygen = LightFamilies.oxygen,
      oxygenSoft = LightFamilies.oxygenSoft,
      stress = LightFamilies.stress,
      stressSoft = LightFamilies.stressSoft,
      stageDeep = LightStagePalette.deep,
      stageLight = LightStagePalette.light,
      stageRem = LightStagePalette.rem,
      stageAwake = LightStagePalette.awake,
      unstaged = LightStagePalette.unstaged;

  /// v02's families, dark. Authored by the prototype, not derived from light.
  const InstrumentHues.dark()
    : fitness = DarkFamilies.fitness,
      fitnessSoft = DarkFamilies.fitnessSoft,
      sleep = DarkFamilies.sleep,
      sleepSoft = DarkFamilies.sleepSoft,
      heart = DarkFamilies.heart,
      heartSoft = DarkFamilies.heartSoft,
      movement = DarkFamilies.movement,
      movementSoft = DarkFamilies.movementSoft,
      oxygen = DarkFamilies.oxygen,
      oxygenSoft = DarkFamilies.oxygenSoft,
      stress = DarkFamilies.stress,
      stressSoft = DarkFamilies.stressSoft,
      stageDeep = DarkStagePalette.deep,
      stageLight = DarkStagePalette.light,
      stageRem = DarkStagePalette.rem,
      stageAwake = DarkStagePalette.awake,
      unstaged = DarkStagePalette.unstaged;

  /// Recovery, HRV, VO₂max, readiness. Also the app's accent.
  final Color fitness;

  /// The fill behind [fitness] content.
  final Color fitnessSoft;

  /// Sleep, sleep debt, sleep timing.
  final Color sleep;

  /// The fill behind [sleep] content.
  final Color sleepSoft;

  /// Heart rate, resting HR, cardio load.
  final Color heart;

  /// The fill behind [heart] content.
  final Color heartSoft;

  /// Steps, distance, calories, energy.
  final Color movement;

  /// The fill behind [movement] content.
  final Color movementSoft;

  /// Respiratory rate, blood oxygen.
  final Color oxygen;

  /// The fill behind [oxygen] content.
  final Color oxygenSoft;

  /// Stress, skin temperature.
  final Color stress;

  /// The fill behind [stress] content.
  final Color stressSoft;

  /// Deep sleep — the lightest rung of the ramp.
  final Color stageDeep;

  /// Light (`core`) sleep — the second rung.
  final Color stageLight;

  /// REM — the third rung.
  final Color stageRem;

  /// Awake — the darkest rung.
  final Color stageAwake;

  /// A span the strap staged with a code this app cannot name. Chroma-free, and
  /// not a fifth rung.
  final Color unstaged;

  /// **The one sleep-stage mapping.** Every hypnogram, stacked bar and legend
  /// resolves a stage name here and nowhere else.
  ///
  /// ```text
  ///   deep          → stageDeep    lightest rung
  ///   core / light  → stageLight
  ///   rem           → stageRem
  ///   awake         → stageAwake   darkest rung
  ///   anything else → unstaged     grey, and named "Unrecognised"
  /// ```
  ///
  /// `core` is the server's word for what the strap calls `light`; one stage,
  /// two vocabularies, one colour.
  ///
  /// The fifth row is not legacy's. Legacy defaults an unrecognised code to
  /// `cSpo2` — it draws a byte nobody has decoded **as light sleep**, which is a
  /// claim rather than a colour choice. So the fifth row is a grey and
  /// `sleepStageLabel` answers "Unrecognised" beside it.
  Color sleepStage(String stage) => switch (stage) {
    'deep' => stageDeep,
    'core' || 'light' => stageLight,
    'rem' => stageRem,
    'awake' => stageAwake,
    _ => unstaged,
  };

  /// Whether [stage] is a code this app can name. The predicate the charts and
  /// their legends share, so a grey band and its key cannot disagree.
  static bool isRecognised(String stage) =>
      const <String>{'deep', 'core', 'light', 'rem', 'awake'}.contains(stage);

  @override
  InstrumentHues copyWith({
    Color? fitness, Color? fitnessSoft,
    Color? sleep, Color? sleepSoft,
    Color? heart, Color? heartSoft,
    Color? movement, Color? movementSoft,
    Color? oxygen, Color? oxygenSoft,
    Color? stress, Color? stressSoft,
    Color? stageDeep, Color? stageLight,
    Color? stageRem, Color? stageAwake,
    Color? unstaged,
  }) {
    return InstrumentHues(
      fitness: fitness ?? this.fitness,
      fitnessSoft: fitnessSoft ?? this.fitnessSoft,
      sleep: sleep ?? this.sleep,
      sleepSoft: sleepSoft ?? this.sleepSoft,
      heart: heart ?? this.heart,
      heartSoft: heartSoft ?? this.heartSoft,
      movement: movement ?? this.movement,
      movementSoft: movementSoft ?? this.movementSoft,
      oxygen: oxygen ?? this.oxygen,
      oxygenSoft: oxygenSoft ?? this.oxygenSoft,
      stress: stress ?? this.stress,
      stressSoft: stressSoft ?? this.stressSoft,
      stageDeep: stageDeep ?? this.stageDeep,
      stageLight: stageLight ?? this.stageLight,
      stageRem: stageRem ?? this.stageRem,
      stageAwake: stageAwake ?? this.stageAwake,
      unstaged: unstaged ?? this.unstaged,
    );
  }

  @override
  InstrumentHues lerp(ThemeExtension<InstrumentHues>? other, double t) {
    if (other is! InstrumentHues) {
      return this;
    }
    return InstrumentHues(
      fitness: Color.lerp(fitness, other.fitness, t)!,
      fitnessSoft: Color.lerp(fitnessSoft, other.fitnessSoft, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      sleepSoft: Color.lerp(sleepSoft, other.sleepSoft, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      heartSoft: Color.lerp(heartSoft, other.heartSoft, t)!,
      movement: Color.lerp(movement, other.movement, t)!,
      movementSoft: Color.lerp(movementSoft, other.movementSoft, t)!,
      oxygen: Color.lerp(oxygen, other.oxygen, t)!,
      oxygenSoft: Color.lerp(oxygenSoft, other.oxygenSoft, t)!,
      stress: Color.lerp(stress, other.stress, t)!,
      stressSoft: Color.lerp(stressSoft, other.stressSoft, t)!,
      stageDeep: Color.lerp(stageDeep, other.stageDeep, t)!,
      stageLight: Color.lerp(stageLight, other.stageLight, t)!,
      stageRem: Color.lerp(stageRem, other.stageRem, t)!,
      stageAwake: Color.lerp(stageAwake, other.stageAwake, t)!,
      unstaged: Color.lerp(unstaged, other.unstaged, t)!,
    );
  }

  /// Every hue, in declaration order. **Add new hues here too** — this backs
  /// equality, and Flutter compares theme extensions to decide whether a theme
  /// change needs a rebuild.
  List<Color> get _hues => [
    fitness, fitnessSoft, sleep, sleepSoft, heart, heartSoft,
    movement, movementSoft, oxygen, oxygenSoft, stress, stressSoft,
    stageDeep, stageLight, stageRem, stageAwake, unstaged,
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

/// Reaches the hue set from a widget: `context.hues.sleep`.
extension InstrumentHuesOf on BuildContext {
  /// The active theme's category families.
  ///
  /// Throws if the theme was built without the extension, which is the right
  /// behaviour — a silent fallback would let a screen render in colours nobody
  /// chose, and look almost right.
  InstrumentHues get hues => Theme.of(this).extension<InstrumentHues>()!;
}
