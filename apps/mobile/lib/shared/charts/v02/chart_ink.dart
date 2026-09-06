/// Every colour a v02 chart uses, resolved **once**, from the tone it sits in.
///
/// ## No chart takes a `Color`
///
/// `tone_scope.dart` states the rule and the reason: a widget that accepts a
/// colour can be handed one that disagrees with the card around it, and nothing
/// catches it — which is how legacy drew cardio load red on one screen and green
/// on another. So a chart reads `context.family` at build time, hands the
/// resulting [ChartInk] to its painter, and the painter has no way to ask for a
/// hue at all.
///
/// ## The alpha bug this file is shaped around
///
/// `Color.withValues(alpha:)` **replaces** alpha, it does not scale it. This app
/// shipped gridlines at 5–7× their intended weight because three painters each
/// derived their own grid ink and then set an absolute alpha on a token that was
/// already translucent (`336d62d`, *"the gridlines were the hairline at five
/// times its alpha"*). So:
///
///   * [grid] and [reference] come from the palette **already quieted**
///     (`palette.dart` derives them: grid is `line` at 50%, reference is `ink3`
///     at 55%) and nothing here touches their alpha except `revealed`, which
///     multiplies.
///   * The area gradient sets an absolute alpha, and that is correct there
///     precisely because a family hue is fully opaque — there is nothing to
///     scale away.
///
/// ## The gradient is per theme, and the glow only exists in one
///
/// The prototype fills every area with one 60%→0 stop. That reads as a wash on
/// a dark ground and as a pastel slab on a white one. Here the fill is three
/// stops with a fast falloff, tuned separately: dark keeps more of the hue
/// because the ground swallows it, light keeps less because it does not.
///
/// The glow — the line redrawn blurred underneath itself — is **dark only**. On
/// `#0D100E` a blurred green under a green line reads as light coming off the
/// trace; on `#F3F6F4` the identical paint reads as a smudge. "Where the ground
/// can carry it" is a real condition, not a hedge.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/shared/charts/chart_primitives.dart';

/// The resolved paint set for one chart.
@immutable
class ChartInk {
  /// Prefer [ChartInk.of]; direct construction is for tests.
  const ChartInk({
    required this.family,
    required this.familySoft,
    required this.grid,
    required this.reference,
    required this.ink3,
    required this.surface,
    required this.isDark,
  });

  /// Resolves the enclosing tone and the theme's chart roles.
  factory ChartInk.of(BuildContext context) {
    final colors = context.colors;
    return ChartInk(
      family: context.family,
      familySoft: context.familySoft,
      grid: colors.grid,
      reference: colors.reference,
      ink3: colors.ink3,
      surface: colors.surface,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  /// Resolves a **named** tone rather than the enclosing one.
  ///
  /// Not a hole in the no-colour rule: a [Tone] is a category, not a hue, so a
  /// caller still cannot hand a chart a colour that disagrees with the palette.
  /// It exists for the linked chart, whose two panes are two categories inside
  /// one card and so cannot both read the card's cascade.
  factory ChartInk.tone(BuildContext context, Tone tone) {
    final theme = Theme.of(context);
    final hues = theme.extension<InstrumentHues>()!;
    final colors = context.colors;
    return ChartInk(
      family: tone.family(hues),
      familySoft: tone.familySoft(hues),
      grid: colors.grid,
      reference: colors.reference,
      ink3: colors.ink3,
      surface: colors.surface,
      isDark: theme.brightness == Brightness.dark,
    );
  }

  /// `var(--family)` — the trace, the bar, the dot. Identity, never verdict.
  final Color family;

  /// `var(--family-soft)` — the ground a bar's shortfall or a band is drawn on.
  final Color familySoft;

  /// The rule inside the plot. Already quieted by the palette; see the
  /// docstring.
  final Color grid;

  /// The line a series is READ AGAINST. Already quieted by the palette.
  final Color reference;

  /// Label ink. Captions and tick values, never a hue.
  final Color ink3;

  /// The card behind the chart — the ring around the last-point dot, so the dot
  /// reads on any fill.
  final Color surface;

  /// Whether the ground can carry a glow. See the docstring.
  final bool isDark;

  /// The tick and caption style. Colourless styles plus this file's one ink.
  TextStyle get labelStyle => TypeScale.colourKey.copyWith(color: ink3);

  /// The area fill under a trace: three stops, tuned per theme, faded by
  /// [progress].
  Shader area(Rect rect, double progress) {
    final t = progress.clamp(0.0, 1.0);
    final top = (isDark ? 0.38 : 0.26) * t;
    final middle = (isDark ? 0.13 : 0.08) * t;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      // The stop at 0.55 is what makes this a body rather than a wash: the hue
      // is nearly spent by mid-plot, so the trace still reads as the loudest
      // thing in its own chart.
      stops: const <double>[0, 0.55, 1],
      colors: <Color>[
        family.withValues(alpha: top),
        family.withValues(alpha: middle),
        family.withValues(alpha: 0),
      ],
    ).createShader(rect);
  }

  /// The trace itself: [width] px, round cap and join.
  Paint stroke(double width) => Paint()
    ..color = family
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// The light under the trace, or null on a ground that cannot carry it.
  Paint? glow(double width) => isDark
      ? (Paint()
          ..color = family.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5))
      : null;

  /// A bar's fill at [emphasis]: 1 for the bar being read, less for its context.
  ///
  /// Weight, not hue — a past day is the same metric as today, so it is the same
  /// colour, quieter. Colouring it differently would say it is a different kind
  /// of thing.
  Paint bar(double emphasis) =>
      Paint()..color = family.withValues(alpha: emphasis.clamp(0.0, 1.0));

  /// The gridline paint at [progress], with the token's own alpha **scaled**.
  Paint gridPaint(double progress) => Paint()
    ..color = revealed(grid, progress)
    ..strokeWidth = 1;

  /// The reference-line paint at [progress]. Same scaling rule as [gridPaint].
  Paint referencePaint(double progress) => Paint()
    ..color = revealed(reference, progress)
    ..strokeWidth = 1;
}
