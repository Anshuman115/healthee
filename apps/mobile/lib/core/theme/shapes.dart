/// The card corner, and it is not a rounded rectangle.
///
/// **Ported from** `healthee-legacy/app/lib/ui/theme.dart`'s `hSquircle`. Legacy
/// draws every module, sheet and badge with a **continuous superellipse** corner
/// at `smoothness 0.6` — Apple's continuous corner, near enough — rather than a
/// circular arc. It is the single most-repeated shape in the app, and swapping it
/// for `RoundedRectangleBorder` changes the look of every card on every screen.
/// So the dependency (`smooth_corner`) travels with the design.
library;

import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// Legacy's `smoothness: 0.6`. Not a taste setting — it is the value the whole
/// design was drawn against.
const double kSquircleSmoothness = 0.6;

/// A continuous-corner rectangle at [radius], optionally with a hairline [side].
///
/// Verbatim from legacy: same smoothness, same parameter shape, same default of
/// no border.
ShapeBorder hSquircle(double radius, {BorderSide side = BorderSide.none}) =>
    HSquircleBorder(
      SmoothRectangleBorder(
        smoothness: kSquircleSmoothness,
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
    );

/// The app's corner: a continuous superellipse that admits how thick its edge is.
///
/// Public and named so a test can ask a surface what shape it drew — the corner
/// radius and the hairline now live inside the `ShapeBorder` rather than on a
/// `BoxDecoration`, and a test that could not read them would have to assert the
/// look of a card by not asserting it.
///
/// ## Why this wrapper exists
///
/// `smooth_corner`'s border returns `EdgeInsets.all(0)` from `dimensions`
/// (v1.1.1, `smooth_rectangle_border.dart:32`) no matter how wide its `side` is.
/// `ShapeDecoration.padding` is exactly that value, so a bordered surface drawn
/// with this shape does NOT inset its child, while the `BoxDecoration` +
/// `Border.all` it replaces does.
///
/// The symptom is small and everywhere: converting the app's cards to the
/// continuous corner moved every bordered panel's content out by one hairline a
/// side — a chart inside a `Panel` went from 352 to 354 px at a 390 px width, and
/// nineteen geometry tests said so. Changing a corner's CURVATURE must not move
/// what is inside it, so the honest repair is here rather than in the
/// expectations.
///
/// Everything else delegates. This adds one fact the wrapped shape already knows
/// and declines to report.
@immutable
class HSquircleBorder extends ShapeBorder {
  const HSquircleBorder(this._shape);

  final SmoothRectangleBorder _shape;

  /// The nominal corner radius, as `hSquircle` was asked for it.
  double get radius => _shape.borderRadius.resolve(null).topLeft.x;

  /// The edge, or [BorderSide.none].
  BorderSide get side => _shape.side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(_shape.side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      _shape.paint(canvas, rect, textDirection: textDirection);

  @override
  ShapeBorder scale(double t) =>
      HSquircleBorder(_shape.scale(t) as SmoothRectangleBorder);

  @override
  bool operator ==(Object other) =>
      other is HSquircleBorder && other._shape == _shape;

  @override
  int get hashCode => _shape.hashCode;
}
