/// `.hero-reading` — one figure, at the size a screen is built around.
///
/// Split out of `surface_panels.dart` at the 400-line gate (Standards section
/// 1). It is the one surface in that file that is not a CARD: the others draw a
/// ground and a border around content, and this draws a number.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// ```
class HeroReading extends StatelessWidget {
  /// [label] sits above the figure and [context_] beneath it.
  const HeroReading({
    required this.label,
    required this.value,
    this.unit,
    this.context_,
    super.key,
  });

  /// `padding-block: 8px 24px`.
  static const EdgeInsets padding = EdgeInsets.only(top: 8, bottom: 24);

  /// `.hero-number { margin-block: 20px 8px }`.
  static const double topGap = 20;

  /// The same, below.
  static const double bottomGap = 8;

  /// What the number is.
  final String label;

  /// The number.
  final String value;

  /// Its unit, at `.duration-unit`'s size.
  final String? unit;

  /// The sentence under it.
  final String? context_;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = TypeScale.small.copyWith(color: colors.ink2);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: small),
          const SizedBox(height: topGap),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: value),
                if (unit case final String unit)
                  TextSpan(
                    text: unit,
                    style: TypeScale.heroUnit.copyWith(color: colors.ink2),
                  ),
              ],
            ),
            style: TypeScale.heroNumber.copyWith(color: colors.ink),
            maxLines: 1,
          ),
          const SizedBox(height: bottomGap),
          if (context_ case final String sentence) Text(sentence, style: small),
        ],
      ),
    );
  }
}
