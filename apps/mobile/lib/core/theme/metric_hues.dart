/// The identity tags, and the ONE table that says which metric wears which.
///
/// A second [ThemeExtension] rather than five more fields on [HealtheeColors],
/// and the split is the point. That class's docstring is emphatic that everything
/// in it is either structure or judgement — "three colours here are allowed to say
/// something about the owner's body" — and a tag is neither. Keeping them in
/// separate extensions means a reviewer reading `colors.unf` beside `hues.heart`
/// can see at the call site that only one of them is a claim.
///
/// ## The invariant this file exists to hold
///
/// **A tag is a function of the metric's IDENTITY and never of its value.**
/// [tagFor] takes a metric id and nothing else — there is deliberately no
/// overload that accepts a reading, a z-score or a direction, so tinting a card by
/// how the owner did today is not something a caller can express. See
/// `palette.dart`'s [LightTagPalette] for why that is what separates a tag from a
/// verdict.
///
/// ## Five families, grouped by what the metric is about
///
/// Legacy gave every metric its own hue. Five cannot, so they are grouped:
///
/// ```text
///   rest     sleep · HRV · readiness            what the body does at rest
///   heart    HR · resting HR · stress           the pump and its load
///   body     breathing · SpO₂ · skin temp       what the body exchanges
///   move     steps · distance · MVPA · load     what the owner did, and the
///            · VO₂max · biological age          fitness it adds up to
///   energy   active · total · basal calories    what it cost
/// ```
///
/// **VO₂max and biological age joined `move`** when the Activity screen was
/// tagged. They defaulted to `rest`, which put the Fitness section in the sleep
/// colour directly under cardio load and active minutes in the movement one —
/// three cards about one subject in two families. They belong here on their own
/// terms too: every instrument that can produce this product's VO₂max reads a
/// recorded session (`gps_graded`, `hr_reserve`) or asks about habitual activity
/// (`jurca_non_exercise`), and biological age's largest term IS that VO₂max.
///
/// The previous set had three, and `body` was carrying breathing, blood oxygen,
/// steps, distance and every calorie at once — a family whose members have nothing
/// in common, which made the tag say only "not sleep and not heart". Splitting the
/// movement and energy metrics out is why the palette grew; `palette.dart` records
/// what the wheel allowed.
///
/// ## Where tags apply, and where the accent still rules
///
/// A tag belongs wherever a card is **about one metric**: the grid, the hypnogram,
/// and now a metric card's chart, its figure accents and its section heading.
/// The accent stays what `tokens.dart` calls it — the colour of an *action*: links,
/// buttons, the disclosure a card offers. Those are things the owner can press,
/// and the one thing worse than a monochrome screen is a screen where the
/// pressable things are not findable.
///
/// A card about several metrics at once keeps the accent too — the daily action,
/// the illness banner, the data-health strip. Nothing there is about one metric,
/// so nothing there has a tag to wear.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/palette.dart';

/// The five identity tags for the active theme.
@immutable
class MetricHues extends ThemeExtension<MetricHues> {
  /// Builds a tag set. Prefer [MetricHues.light] / [MetricHues.dark].
  const MetricHues({
    required this.rest,
    required this.heart,
    required this.body,
    required this.move,
    required this.energy,
  });

  /// The approved tags, light.
  const MetricHues.light()
    : rest = LightTagPalette.rest,
      heart = LightTagPalette.heart,
      body = LightTagPalette.body,
      move = LightTagPalette.move,
      energy = LightTagPalette.energy;

  /// The approved tags, dark.
  const MetricHues.dark()
    : rest = DarkTagPalette.rest,
      heart = DarkTagPalette.heart,
      body = DarkTagPalette.body,
      move = DarkTagPalette.move,
      energy = DarkTagPalette.energy;

  /// Sleep, HRV, readiness — and the deep-sleep band on a hypnogram.
  final Color rest;

  /// Heart rate, resting heart rate, stress — and the REM band.
  final Color heart;

  /// Breathing, blood oxygen, skin temperature — and the light-sleep band.
  final Color body;

  /// Steps, distance, active minutes, cardio load — and the fitness they add up
  /// to: VO₂max and biological age.
  final Color move;

  /// Calories, in every form.
  final Color energy;

  /// The tag for a canonical metric id, defaulting to [rest].
  ///
  /// Ids are the server's (`rhr_daily`, `steps_total`) and the strap's
  /// (`resting_hr`, `spo2`), because both halves of Today draw modules and a
  /// second table keyed by a second vocabulary is how one metric ends up two
  /// colours. An id nobody listed gets [rest] rather than a distinct "unknown"
  /// hue: a new metric should look like it belongs, not like an error.
  Color tagFor(String metric) => switch (metric) {
    'rhr_daily' ||
    'resting_hr' ||
    'hr' ||
    'heart_rate' ||
    'max_hr' ||
    'stress' ||
    'stress_daily' => heart,
    'respiratory_rate' ||
    'respiratory_rate_sleep' ||
    'spo2' ||
    'spo2_overnight' ||
    'spo2_overnight_min' ||
    'temperature_c' ||
    'skin_temp_c' => body,
    'steps_total' ||
    'steps' ||
    'steps_per_minute' ||
    'distance_m' ||
    'distance_m_daily' ||
    'mvpa_min' ||
    'moderate_min' ||
    'vigorous_min' ||
    'cardio_load' ||
    'cardio_load_trimp' ||
    'vo2max_estimate' ||
    'vo2max_submax' ||
    'biological_age' => move,
    'active_calories' ||
    'total_calories' ||
    'basal_calories' => energy,
    _ => rest,
  };

  @override
  MetricHues copyWith({
    Color? rest,
    Color? heart,
    Color? body,
    Color? move,
    Color? energy,
  }) => MetricHues(
    rest: rest ?? this.rest,
    heart: heart ?? this.heart,
    body: body ?? this.body,
    move: move ?? this.move,
    energy: energy ?? this.energy,
  );

  @override
  MetricHues lerp(ThemeExtension<MetricHues>? other, double t) {
    if (other is! MetricHues) {
      return this;
    }
    return MetricHues(
      rest: Color.lerp(rest, other.rest, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      body: Color.lerp(body, other.body, t)!,
      move: Color.lerp(move, other.move, t)!,
      energy: Color.lerp(energy, other.energy, t)!,
    );
  }

  /// Every tag, in declaration order. **Add a new tag here too** — this backs
  /// equality, and Flutter compares theme extensions to decide whether a theme
  /// change needs a rebuild.
  List<Color> get _tags => <Color>[rest, heart, body, move, energy];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! MetricHues) {
      return false;
    }
    final mine = _tags;
    final theirs = other._tags;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_tags);
}

/// Reaches the tag set from a widget: `context.hues.heart`.
extension MetricHuesOf on BuildContext {
  /// The active theme's identity tags.
  ///
  /// Throws when the theme was built without the extension, for the same reason
  /// `context.colors` does: a silent fallback would let a screen render in
  /// colours nobody chose and look almost right.
  MetricHues get hues => Theme.of(this).extension<MetricHues>()!;
}
