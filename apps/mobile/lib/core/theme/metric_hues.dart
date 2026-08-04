/// The identity tags, and the ONE table that says which metric wears which.
///
/// A second [ThemeExtension] rather than three more fields on [HealtheeColors],
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
/// ## Why the assignment is grouped rather than per-metric
///
/// Legacy gave every metric its own hue. Three tags cannot, so they are grouped by
/// what the metric is *about* — rest, heart, body — which is more legible than
/// seven near-identical blues would have been and survives new metrics without a
/// palette change. Two modules in one grid row may share a tag; the label above
/// them is what names the metric, and the dot only ever said which family it
/// belongs to.
///
/// ## Where tags apply, and where the accent still rules
///
/// Tags are the **grid's** language and the **hypnogram's**: a dense index where
/// several metrics sit side by side needs each cell tied to its own chart, and a
/// four-lane sleep chart needs bands that can be told apart. Everywhere else on
/// Today — the debt bars, the VO₂max trend, the stress hours, the recovery ladder
/// — a card is titled and alone, and its line stays [HealtheeColors.accent],
/// which `tokens.dart` defines as "the owner's own data line".
///
/// That boundary is deliberate rather than unfinished work. Spending three hues
/// on a screen where nothing needs telling apart would make the tags decorative,
/// and a decorative colour in this app is one that will eventually be read as a
/// claim.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/palette.dart';

/// The three identity tags for the active theme.
@immutable
class MetricHues extends ThemeExtension<MetricHues> {
  /// Builds a tag set. Prefer [MetricHues.light] / [MetricHues.dark].
  const MetricHues({required this.rest, required this.heart, required this.body});

  /// The approved tags, light.
  const MetricHues.light()
    : rest = LightTagPalette.rest,
      heart = LightTagPalette.heart,
      body = LightTagPalette.body;

  /// The approved tags, dark.
  const MetricHues.dark()
    : rest = DarkTagPalette.rest,
      heart = DarkTagPalette.heart,
      body = DarkTagPalette.body;

  /// Sleep, HRV, readiness — and the deep-sleep band on a hypnogram.
  final Color rest;

  /// Heart rate, resting heart rate, stress — and the REM band.
  final Color heart;

  /// Steps, energy, breathing, blood oxygen — and the light-sleep band.
  final Color body;

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
    'steps_total' ||
    'steps' ||
    'distance_m_daily' ||
    'active_calories' ||
    'total_calories' ||
    'basal_calories' ||
    'respiratory_rate' ||
    'respiratory_rate_sleep' ||
    'spo2' ||
    'spo2_overnight' ||
    'spo2_overnight_min' ||
    'temperature_c' => body,
    _ => rest,
  };

  @override
  MetricHues copyWith({Color? rest, Color? heart, Color? body}) => MetricHues(
    rest: rest ?? this.rest,
    heart: heart ?? this.heart,
    body: body ?? this.body,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetricHues &&
          other.rest == rest &&
          other.heart == heart &&
          other.body == body);

  @override
  int get hashCode => Object.hash(rest, heart, body);
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
