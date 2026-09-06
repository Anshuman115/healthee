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
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';

/// The biological-age hero.
class BioHero extends StatelessWidget {
  /// Builds the hero. [stats] is drawn as a two-column grid under the rule.
  const BioHero({
    required this.eyebrow,
    required this.value,
    this.eyebrowIcon,
    this.unit,
    this.caption,
    this.instrument,
    this.stats = const <BioStat>[],
    this.modelLabel,
    this.modelIcon,
    this.art,
    this.artFillsCard = false,
    this.centred = false,
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

  /// The reading drawn on a scale, between the caption and the rule.
  ///
  /// `panels.js` puts `H.charts.ageScale()` exactly here. It is a slot rather
  /// than a hard-wired `AgeScale` because the hero is not only the age card —
  /// the same shape carries VO₂max on Activity — and a hero that named its own
  /// instrument would have to grow a second one for each.
  final Widget? instrument;

  /// The two statistics under the rule.
  final List<BioStat> stats;

  /// Which instrument produced the figure.
  final String? modelLabel;

  /// Drawn before [modelLabel].
  final IconData? modelIcon;

  /// The decorative contour behind everything. Optional and purely visual.
  final Widget? art;

  /// `motion.css`'s override of `.bio-art`, for a live field rather than a
  /// static contour:
  ///
  /// ```css
  /// .bio-hero .bio-art        { inset:0; width:100%; height:100%; opacity:1 }
  /// .bio-hero .bio-atmosphere { opacity: .9 }
  /// ```
  ///
  /// False keeps `richer.css`'s 300 x 230 box at `right: -60px`, which is what a
  /// drawn contour wants. True fills the card, which is what a particle field
  /// wants — the ring is meant to sit **around** the figure, not beside it.
  final bool artFillsCard;

  /// `motion.css`'s `.bio-display`: the figure centred in a square, with its
  /// unit on its own line under it rather than beside it.
  ///
  /// ```css
  /// .bio-display  { width:100%; max-width:304px; aspect-ratio:1;
  ///                 display:grid; place-items:center; margin:0 auto }
  /// .age-value    { margin:0; text-align:center; font-size:84px;
  ///                 letter-spacing:-5px }
  /// .age-value small { display:block; margin:4px 0 0; font-size:11px;
  ///                    letter-spacing:1px }
  /// ```
  ///
  /// Default false, so every caller written against `richer.css` alone is
  /// unchanged. It is opt-in rather than inferred from [artFillsCard] because
  /// they are two different stylesheets' decisions and a hero may want either.
  final bool centred;

  /// `.bio-art { opacity: 1 }` with `.bio-atmosphere`'s own `.9` on top of it.
  static const double fieldOpacity = 0.9;

  /// `.bio-display { max-width: 304px }`.
  static const double displayMaxWidth = 304;

  /// `motion.css`: `.age-value small { margin: 4px 0 0 }`.
  static const double centredUnitGap = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.bioInk;
    final rule = colors.bioLine.withValues(alpha: colors.bioLine.a * lineMix);
    final scope = CaveatScope.of(context);
    final disclosed = scope?.caveats ?? const <Disclosure>[];
    return CaveatScope(
      caveats: const <Disclosure>[],
      child: _card(colors, ink, rule, scope, disclosed),
    );
  }

  Widget _card(
    HealtheeColors colors,
    Color ink,
    Color rule,
    CaveatScope? scope,
    List<Disclosure> disclosed,
  ) {
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
            if (artFillsCard)
              Positioned.fill(
                child: Opacity(opacity: fieldOpacity, child: art),
              )
            else
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
                if (instrument case final Widget scale) ...<Widget>[
                  const SizedBox(height: captionGap),
                  _inset(scale),
                ],
                if (stats.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ruleGap),
                  SizedBox(height: hairline, child: ColoredBox(color: rule)),
                  const SizedBox(height: statsGap),
                  _inset(BioStatsRow(stats: stats, ink: ink)),
                ],
                if (modelLabel != null) ...<Widget>[
                  const SizedBox(height: modelGap),
                  _inset(BioModelLabel(label: modelLabel!, icon: modelIcon, ink: ink)),
                ],
                // The hero is a card, so the hero is a caveat carrier. A
                // `ReadingView` with `CaveatCarrier.insideCard` hands its
                // disclosures down a `CaveatScope` and draws nothing itself; a
                // card that did not read it would drop the sentence silently,
                // which is the one failure the honesty layer exists to prevent.
                // `panel.dart` carries the same block for the same reason.
                if (disclosed.isNotEmpty) ...<Widget>[
                  const SizedBox(height: modelGap),
                  _inset(CaveatNote(caveats: disclosed, label: scope?.label)),
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

  Widget _value(Color ink) => centred ? _centredValue(ink) : _inlineValue(ink);

  /// `motion.css`'s `.bio-display`: a square, the figure in the middle of it,
  /// the unit under the figure. The square is what puts the halo's ring around
  /// the number instead of behind one corner of it.
  Widget _centredValue(Color ink) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: displayMaxWidth),
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              value,
              textAlign: TextAlign.center,
              style: TypeScale.bioAgeCentred.copyWith(color: ink),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
            if (unit != null) ...<Widget>[
              const SizedBox(height: centredUnitGap),
              Text(
                unit!,
                textAlign: TextAlign.center,
                style: TypeScale.bioAgeUnitCentred.copyWith(color: ink),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _inlineValue(Color ink) => Row(
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

}
