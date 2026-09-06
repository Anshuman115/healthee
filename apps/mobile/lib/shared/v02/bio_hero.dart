/// `.bio-hero` — the biological-age hero, the one 88 px figure in the product.
///
/// ```css
/// .bio-hero              { padding: 22px; border-radius: 28px;
///                          background: var(--bio-background);
///                          color: var(--bio-ink); overflow: clip;
///                          border: 1px solid
///                            color-mix(in oklch, var(--bio-line) 35%, var(--surface)); }
/// .bio-hero .bio-art     { position:absolute; right:-60px; top:18px;
///                          width:300px; height:230px; opacity:.6; z-index:-1; }
/// .bio-eyebrow           { display:flex; justify-content:space-between;
///                          font-size:12px; font-weight:600; }
/// .bio-eyebrow .icon     { width: 17px; }
/// .age-value             { font-size:88px; line-height:1; letter-spacing:-6px;
///                          font-weight:600; margin-top:20px; }
/// .age-value small       { font-size:13px; font-weight:400; margin-left:8px; }
/// .age-context           { font-size:12px; margin-block:12px 18px; }
/// .bio-divider           { border-top:1px solid
///                            color-mix(in oklch,var(--bio-line) 35%,transparent);
///                          margin:16px -22px 0; padding:14px 22px 0; }
/// .bio-bottom            { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
/// .bio-bottom span       { font-size:10px; opacity:.85; }
/// .bio-bottom strong     { font-size:17px; font-weight:600; }
/// .model-label           { font-size:9px; margin-top:14px; opacity:.8; gap:5px; }
/// .model-label .icon     { width: 11px; }
/// ```
///
/// **This card has its own dark surface in both themes**, which is why
/// `bioBackground` / `bioInk` are tokens rather than `surface` / `ink`. Nothing
/// inside it may reach for the page's ink.
///
/// ## Two CSS constructs with no Flutter equivalent, and what was drawn instead
///
/// `color-mix(in oklch, X 35%, Y)` interpolates in OKLab; `Color.lerp` interpolates
/// in sRGB. On a 1 px hairline and a divider the two are indistinguishable, so the
/// border is `Color.lerp(bioLine, surface, 0.65)` and the divider is `bioLine` at
/// 35 % alpha (`color-mix` with `transparent` is exactly an alpha).
///
/// The divider's `margin: 16px -22px 0` is a **full-bleed rule inside a padded
/// box**. Rather than negative margins, the hero pads each child horizontally and
/// leaves the rule at full width — the rendered result is identical and there is
/// no negative geometry to get wrong. The 16 px above the rule and the 18 px below
/// `.age-context` are adjacent CSS margins, which collapse to **18**; that is the
/// number used.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';

/// One of the two statistics under the hero's rule.
@immutable
class BioStat {
  /// Builds a statistic: a small [label] over a larger [value].
  const BioStat(this.label, this.value);

  /// `.bio-bottom span`.
  final String label;

  /// `.bio-bottom strong`.
  final String value;
}

/// The biological-age hero.
class BioHero extends StatelessWidget {
  /// Builds the hero. [stats] is drawn as a two-column grid under the rule.
  const BioHero({
    required this.eyebrow,
    required this.value,
    this.eyebrowIcon,
    this.unit,
    this.caption,
    this.stats = const <BioStat>[],
    this.modelLabel,
    this.modelIcon,
    this.art,
    super.key,
  });

  /// `padding: 22px`.
  static const double padding = 22;

  /// `border-radius: 28px`.
  static const double radius = 28;

  /// `.bio-eyebrow .icon { width: 17px }`.
  static const double eyebrowIconSize = 17;

  /// `.age-value { margin-top: 20px }`.
  static const double valueGap = 20;

  /// `.age-value small { margin-left: 8px }`.
  static const double unitGap = 8;

  /// `.age-context { margin-block: 12px … }`.
  static const double captionGap = 12;

  /// `.age-context`'s 18 collapsed with `.bio-divider`'s 16. See the docstring.
  static const double ruleGap = 18;

  /// `.bio-divider { padding-top: 14px }`.
  static const double statsGap = 14;

  /// `.bio-bottom { gap: 16px }`.
  static const double statsSpacing = 16;

  /// `.model-label { margin-top: 14px }`.
  static const double modelGap = 14;

  /// `.model-label .icon { width: 11px }`, and its `gap: 5px`.
  static const double modelIconSize = 11;

  /// `.model-label { gap: 5px }`.
  static const double modelIconGap = 5;

  /// The share of `bioLine` in the border and the rule — `color-mix … 35%`.
  static const double lineMix = 0.35;

  /// `.bio-art` geometry, measured from the padding box.
  static const Rect artRect = Rect.fromLTWH(0, 18, 300, 230);

  /// `.bio-art { right: -60px }`.
  static const double artRight = -60;

  /// `.bio-art { opacity: .6 }`.
  static const double artOpacity = 0.6;

  /// The label row above the figure.
  final String eyebrow;

  /// Drawn at the right of the eyebrow row.
  final IconData? eyebrowIcon;

  /// The figure itself.
  final String value;

  /// Its unit, drawn small and beside it.
  final String? unit;

  /// The sentence under the figure.
  final String? caption;

  /// The two statistics under the rule.
  final List<BioStat> stats;

  /// Which instrument produced the figure.
  final String? modelLabel;

  /// Drawn before [modelLabel].
  final IconData? modelIcon;

  /// The decorative contour behind everything. Optional and purely visual.
  final Widget? art;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.bioInk;
    final rule = colors.bioLine.withValues(alpha: colors.bioLine.a * lineMix);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.bioBackground,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Color.lerp(colors.bioLine, colors.surface, 1 - lineMix)!,
          width: hairline,
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (art != null)
            Positioned(
              right: artRight,
              top: artRect.top,
              width: artRect.width,
              height: artRect.height,
              child: Opacity(opacity: artOpacity, child: art),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _inset(_eyebrow(ink)),
                const SizedBox(height: valueGap),
                _inset(_value(ink)),
                if (caption != null) ...<Widget>[
                  const SizedBox(height: captionGap),
                  _inset(
                    Text(
                      caption!,
                      style: TypeScale.bioContext.copyWith(color: ink),
                    ),
                  ),
                ],
                if (stats.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ruleGap),
                  SizedBox(height: hairline, child: ColoredBox(color: rule)),
                  const SizedBox(height: statsGap),
                  _inset(_stats(ink)),
                ],
                if (modelLabel != null) ...<Widget>[
                  const SizedBox(height: modelGap),
                  _inset(_model(ink)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: padding),
    child: child,
  );

  Widget _eyebrow(Color ink) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          eyebrow,
          style: TypeScale.bioEyebrow.copyWith(color: ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (eyebrowIcon != null)
        Icon(eyebrowIcon, size: eyebrowIconSize, color: ink),
    ],
  );

  Widget _value(Color ink) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: <Widget>[
      Flexible(
        child: Text(
          value,
          style: TypeScale.bioAge.copyWith(color: ink),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ),
      if (unit != null) ...<Widget>[
        const SizedBox(width: unitGap),
        Text(unit!, style: TypeScale.bioAgeUnit.copyWith(color: ink)),
      ],
    ],
  );

  Widget _stats(Color ink) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (var i = 0; i < stats.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: statsSpacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                stats[i].label,
                style: TypeScale.bioStatLabel.copyWith(
                  color: ink.withValues(alpha: ink.a * 0.85),
                ),
              ),
              Text(
                stats[i].value,
                style: TypeScale.bioStat.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _model(Color ink) {
    final faded = ink.withValues(alpha: ink.a * 0.8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (modelIcon != null) ...<Widget>[
          Icon(modelIcon, size: modelIconSize, color: faded),
          const SizedBox(width: modelIconGap),
        ],
        Flexible(
          child: Text(
            modelLabel!,
            style: TypeScale.modelLabel.copyWith(color: faded),
          ),
        ),
      ],
    );
  }
}
