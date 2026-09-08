/// `.bio-display` — the square the biological-age figure stands in, the figure
/// itself, and where the field behind it keeps its hole.
///
/// ```css
/// .bio-display     { position:relative; width:100%; max-width:304px;
///                    aspect-ratio:1; display:grid; place-items:center; }
/// .age-value       { margin:0; text-align:center; font-size:84px;
///                    letter-spacing:-5px }
/// .age-value small { display:block; margin:4px 0 0; font-size:11px }
/// ```
///
/// ## The square is CONTENT, and it is the card's tallest term
///
/// `.bio-display` is an ordinary grid box with `aspect-ratio: 1`: its side is
/// the content width, capped at 304, and **the card's height follows from it**.
/// The two canvases in the prototype are both `position: absolute` — the field
/// is sized *by* the box it sits in and never the other way round. That is the
/// whole geometry of this hero, and [bioStillCentre] is the arithmetic that
/// keeps the field's hole over the figure once the field is stretched across the
/// **card** rather than across the square.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_bio.dart';

/// `.bio-hero { padding: 22px }`.
const double kBioHeroPadding = 22;

/// `.bio-display { max-width: 304px }`.
const double kBioDisplayMaxWidth = 304;

/// The eyebrow row's height in the motion layout.
///
/// `.bio-controls .motion-toggle { width:32px; height:32px }` — the pause
/// control, not the 12 px label, is what sets this row's height in the
/// prototype. Pinning it makes the row a **known** term, which is what lets
/// [bioStillCentre] place the hole without measuring anything.
const double kBioEyebrowExtent = 32;

/// The side `.bio-display` takes inside a card [width] px wide.
double bioDisplaySide(double width) =>
    math.min(math.max(width - kBioHeroPadding * 2, 0), kBioDisplayMaxWidth);

/// Where the field's still centre belongs, inside a card of [card].
///
/// `motion.css` stretches `.bio-art` over the whole card (`inset: 0`) while the
/// ring it draws belongs around the **figure** — in the prototype that is two
/// canvases, one per box. This app draws one field, so the hole is moved instead
/// of the canvas: the square starts at `padding + eyebrow` and is
/// [bioDisplaySide] tall, so its centre is a number the card's own size gives.
///
/// A field centred on the *card* instead puts its densest rim across the figure
/// and its hole over the sentence and the ruler, which is the legibility failure
/// this exists to prevent.
Alignment bioStillCentre(Size card) {
  if (card.height <= 0) {
    return Alignment.center;
  }
  final centre =
      kBioHeroPadding + kBioEyebrowExtent + bioDisplaySide(card.width) / 2;
  return Alignment(0, (2 * centre / card.height) - 1);
}

/// Hands the field under a hero the still centre worked out for that card.
///
/// An inherited value rather than a constructor argument because the art is a
/// **slot** on the hero: the card is handed an opaque widget and cannot rebuild
/// it with a different alignment. The default is [Alignment.center], so a field
/// pumped on its own is unchanged.
class BioDisplayScope extends InheritedWidget {
  /// Publishes [stillCentre] to everything under [child].
  const BioDisplayScope({
    required this.stillCentre,
    required super.child,
    super.key,
  });

  /// Where the hole goes, as a fraction of the field's own box.
  final Alignment stillCentre;

  /// The still centre in scope, or [Alignment.center] when there is none.
  static Alignment of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BioDisplayScope>()
          ?.stillCentre ??
      Alignment.center;

  @override
  bool updateShouldNotify(BioDisplayScope oldWidget) =>
      oldWidget.stillCentre != stillCentre;
}

/// `.age-value` — the one 88 px figure in the product, in either of its layouts.
class BioFigure extends StatelessWidget {
  /// Builds the figure. [centred] selects `motion.css`'s square display over
  /// `richer.css`'s inline figure-and-unit.
  const BioFigure({
    required this.value,
    this.unit,
    this.centred = false,
    super.key,
  });

  /// `.age-value small { margin-left: 8px }`.
  static const double unitGap = 8;

  /// `motion.css`: `.age-value small { margin: 4px 0 0 }`.
  static const double centredUnitGap = 4;

  /// The figure itself.
  final String value;

  /// Its unit, drawn small.
  final String? unit;

  /// Whether to draw the square display rather than the inline figure.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.bioInk;
    return centred ? _centred(ink) : _inline(ink);
  }

  /// A square, the figure in the middle of it, the unit under the figure. The
  /// square is what puts the field's ring around the number rather than behind
  /// one corner of it — and it is the card's tallest content term.
  Widget _centred(Color ink) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kBioDisplayMaxWidth),
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              value,
              textAlign: TextAlign.center,
              style: BioType.bioAgeCentred.copyWith(color: ink),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
            if (unit != null) ...<Widget>[
              const SizedBox(height: centredUnitGap),
              Text(
                unit!,
                textAlign: TextAlign.center,
                style: BioType.bioAgeUnitCentred.copyWith(color: ink),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _inline(Color ink) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      Flexible(
        child: Text(
          value,
          style: BioType.bioAge.copyWith(color: ink),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ),
      if (unit != null) ...<Widget>[
        const SizedBox(width: unitGap),
        Text(unit!, style: BioType.bioAgeUnit.copyWith(color: ink)),
      ],
    ],
  );
}
