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
/// .bio-controls          { display:flex; align-items:center; gap:12px; }
/// .age-value             { font-size:88px; line-height:1; letter-spacing:-6px;
///                          font-weight:600; margin-top:20px; }
/// .age-context           { font-size:12px; margin-block:12px 18px; }
/// .bio-divider           { border-top:1px solid
///                            color-mix(in oklch,var(--bio-line) 35%,transparent);
///                          margin:16px -22px 0; padding:14px 22px 0; }
/// .bio-bottom            { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
/// .model-label           { font-size:9px; margin-top:14px; opacity:.8; gap:5px; }
/// ```
///
/// **This card has its own dark surface in both themes**, which is why
/// `bioBackground` / `bioInk` are tokens rather than `surface` / `ink`. Nothing
/// inside it may reach for the page's ink.
///
/// ## THE ART IS A BACKGROUND LAYER. THE CONTENT MAKES THE HEIGHT.
///
/// Both `.bio-art` rules are `position: absolute`, so in the prototype the field
/// is **sized by the card** and takes part in no layout: `inset: 0` under
/// `motion.css`, a 300 x 230 box at `right: -60px` under `richer.css`, and
/// `z-index: -1` under the content either way, clipped to the 28 px radius by
/// `overflow: clip`. Here that is a `Positioned` first child of a `Stack` inside
/// a clipping `Container` — positioned, so it cannot contribute a single pixel
/// of height, and first, so it paints behind everything.
///
/// The height therefore comes from the content, and the tallest term in it is
/// `.bio-display`'s square (`bio_display.dart`), not the field.
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
/// no negative geometry to get wrong.
///
/// ## The vertical gaps, and which stylesheet each one comes from
///
/// CSS margins between siblings collapse, so each gap below is stated once, at
/// the size the browser actually leaves:
///
///   * [valueGap] 20 — `.age-value { margin-top: 20px }`, `richer.css` only.
///     `motion.css` resets it (`.age-value { margin: 0 }`), so the centred
///     display sits directly under the eyebrow.
///   * [captionGap] 12 — `.age-context { margin-top: 12px }`, `richer.css` only;
///     `motion.css` resets it too (`margin: 0 0 18px`).
///   * [contextGap] 18 — `.age-context { margin-bottom: 18px }`, before the ruler.
///   * [dividerGap] 16 — `.bio-divider { margin-top: 16px }`, when something
///     other than the caption is above the rule.
///   * [ruleGap] 18 — the caption's 18 **collapsed** with the divider's 16, for
///     the layout that has no ruler between them.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/states/caveat_disclosure.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/v02/bio_display.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';

/// The biological-age hero.
class BioHero extends StatelessWidget {
  /// Builds the hero. [stats] is drawn as a two-column grid under the rule.
  const BioHero({
    required this.eyebrow,
    required this.value,
    this.eyebrowIcon,
    this.eyebrowAction,
    this.onEyebrowTap,
    this.eyebrowSemantics,
    this.unit,
    this.caption,
    this.figure,
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
  static const double padding = kBioHeroPadding;

  /// `border-radius: 28px`.
  static const double radius = 28;

  /// `.bio-eyebrow .icon { width: 17px }`.
  static const double eyebrowIconSize = 17;

  /// `.bio-controls { gap: 12px }` — between the action and the arrow.
  static const double controlsGap = 12;

  /// The eyebrow row's own height in the motion layout. See [kBioEyebrowExtent].
  static const double eyebrowExtent = kBioEyebrowExtent;

  /// `.age-value { margin-top: 20px }`. See the docstring: `richer.css` only.
  static const double valueGap = 20;

  /// `.age-context { margin-top: 12px }`. `richer.css` only.
  static const double captionGap = 12;

  /// `.age-context { margin-bottom: 18px }`.
  static const double contextGap = 18;

  /// `.bio-divider { margin-top: 16px }`.
  static const double dividerGap = 16;

  /// The caption's 18 collapsed with the divider's 16. See the docstring.
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

  /// `.bio-art { opacity: 1 }` with `.bio-atmosphere`'s own `.9` on top of it.
  static const double fieldOpacity = 0.9;

  /// The label row above the figure.
  final String eyebrow;

  /// Drawn at the right of the eyebrow row.
  final IconData? eyebrowIcon;

  /// A control at the right of the eyebrow row, before [eyebrowIcon].
  ///
  /// `.bio-controls` — the hero's ⓘ lives here. It is
  /// a slot rather than an `infoKey` because the dot has to be given the hero's
  /// own ink: this card has its own dark surface in both themes, and nothing
  /// inside it may reach for the page's ink.
  final Widget? eyebrowAction;

  /// Where the eyebrow's arrow goes.
  ///
  /// `panels.js::H.bioHero` wraps it in
  /// `<a href="#body" aria-label="Understand your biological age">`, so the
  /// arrow has always been the doorway rather than decoration. Null draws the
  /// glyph with no tap, which is what a hero with nowhere to go should look
  /// like.
  final VoidCallback? onEyebrowTap;

  /// What that arrow is called for a screen reader — the prototype's own
  /// `aria-label`. Falls back to [eyebrow].
  final String? eyebrowSemantics;

  /// The figure itself.
  ///
  /// Always supplied, even when [figure] replaces the drawing of it: it is what
  /// a screen reader is given, and a hero with no spoken value would be silent
  /// rather than merely refusing.
  final String value;

  /// Its unit, drawn small and beside it.
  final String? unit;

  /// The sentence under the figure.
  final String? caption;

  /// Draws the figure slot instead of [value], for a hero whose number is not a
  /// current reading.
  ///
  /// The withheld hero uses it (`today_hero_withheld.dart`): a refused hero is
  /// still a hero — same ground, radius, padding and eyebrow — but what stands
  /// in the figure's place is either a dash or a **dated** last-known value, and
  /// neither is a `String` the two type scales here could draw honestly.
  final Widget? figure;

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

  /// The decorative field behind everything. Optional, purely visual, and
  /// **always positioned**, so it never takes part in the card's height.
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
  /// drawn contour wants. True stretches the field across the card, which is what
  /// a particle field wants — and hands it the still centre
  /// ([bioStillCentre]) that keeps its hole over the figure.
  final bool artFillsCard;

  /// `motion.css`'s `.bio-display`: the figure centred in a square, with its
  /// unit on its own line under it rather than beside it. Default false, so
  /// every caller written against `richer.css` alone is unchanged.
  final bool centred;

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
          // FIRST, so it paints behind the content, and POSITIONED, so the
          // card's height is the content's and never the field's.
          if (art != null) _art(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: _content(ink, rule, scope, disclosed),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(
    Color ink,
    Color rule,
    CaveatScope? scope,
    List<Disclosure> disclosed,
  ) => <Widget>[
    _inset(_eyebrow(ink)),
    if (!centred) const SizedBox(height: valueGap),
    _inset(figure ?? BioFigure(value: value, unit: unit, centred: centred)),
    if (caption case final String sentence) ...<Widget>[
      if (!centred) const SizedBox(height: captionGap),
      _inset(Text(sentence, style: TypeScale.bioContext.copyWith(color: ink))),
    ],
    if (instrument case final Widget scale) ...<Widget>[
      if (caption != null) const SizedBox(height: contextGap),
      _inset(scale),
    ],
    if (stats.isNotEmpty) ...<Widget>[
      SizedBox(
        height: caption != null && instrument == null ? ruleGap : dividerGap,
      ),
      SizedBox(height: hairline, child: ColoredBox(color: rule)),
      const SizedBox(height: statsGap),
      _inset(BioStatsRow(stats: stats, ink: ink)),
    ],
    if (modelLabel case final String label) ...<Widget>[
      const SizedBox(height: modelGap),
      _inset(BioModelLabel(label: label, icon: modelIcon, ink: ink)),
    ],
    // The hero is a card, so the hero is a caveat carrier. A `ReadingView` with
    // `CaveatCarrier.insideCard` hands its disclosures down a `CaveatScope` and
    // draws nothing itself; a card that did not read it would drop the sentence
    // silently, which is the one failure the honesty layer exists to prevent.
    // `panel.dart` carries the same block for the same reason.
    if (disclosed.isNotEmpty) ...<Widget>[
      const SizedBox(height: modelGap),
      _inset(CaveatNote(caveats: disclosed, label: scope?.label)),
    ],
  ];

  /// `.bio-art`, in whichever of its two boxes. Positioned either way.
  Widget _art() {
    if (!artFillsCard) {
      return Positioned(
        right: artRight,
        top: artRect.top,
        width: artRect.width,
        height: artRect.height,
        child: Opacity(opacity: artOpacity, child: art),
      );
    }
    return Positioned.fill(
      // The constraints here are the card's finished size — a positioned child
      // is laid out against the stack, which is laid out against the content —
      // so this is where the still centre can be worked out at all.
      child: LayoutBuilder(
        builder: (context, constraints) => BioDisplayScope(
          stillCentre: centred
              ? bioStillCentre(constraints.biggest)
              : Alignment.center,
          child: Opacity(opacity: fieldOpacity, child: art),
        ),
      ),
    );
  }

  Widget _inset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: padding),
    child: child,
  );

  Widget _eyebrow(Color ink) => ConstrainedBox(
    // `.bio-controls .motion-toggle` is 32 px tall and it, not the 12 px label,
    // sets this row's height in the motion layout. Pinned so the still centre
    // is arithmetic rather than a measurement.
    constraints: BoxConstraints(minHeight: centred ? eyebrowExtent : 0),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            eyebrow,
            style: TypeScale.bioEyebrow.copyWith(color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (eyebrowAction case final Widget action) action,
        if (eyebrowAction != null && eyebrowIcon != null)
          const SizedBox(width: controlsGap),
        if (eyebrowIcon != null)
          HTap(
            onTap: onEyebrowTap,
            semanticLabel: eyebrowSemantics ?? eyebrow,
            child: Icon(eyebrowIcon, size: eyebrowIconSize, color: ink),
          ),
      ],
    ),
  );
}
