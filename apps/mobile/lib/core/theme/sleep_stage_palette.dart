/// **The four sleep-stage colours, and the unrecognised grey.** The second — and
/// only other — file in this app that may hold a colour literal; `palette.dart`
/// is the first, and its library docstring names this one.
///
/// ## Why this is not in `palette.dart`, and not legacy's values
///
/// Legacy has no stage palette. `HColors.sleepStage` *borrows* four metric hues
/// — `cSteps` for deep, `cSpo2` for light, `cSleep` for REM, `cHeart` for awake —
/// and the port carried that borrowing over verbatim. On the installed dark build
/// the owner reported the result: *"the sleep graph … looks dull and has
/// accessibility issues, only yellow is visible, others are not."*
///
/// He was right, and the reason is measurable. Each of the four clears the card
/// it is drawn on comfortably; what they do not clear is **each other**:
///
/// ```text
///   dark, against the card #141419      dark, band against band
///     deep   #D9A84E   8.45:1             rem   vs awake   1.02:1
///     light  #7DA3C4   6.91:1             light vs awake   1.11:1
///     rem    #968EC9   6.13:1             light vs rem     1.13:1
///     awake  #E07A5F   6.22:1             deep  vs light   1.22:1
///                                         deep  vs awake   1.36:1
///                                         deep  vs rem     1.38:1
///   light, against the card #FFFFFF     light, band against band
///     deep   #B27F2C   3.52:1             light vs awake   1.12:1
///     light  #587A97   4.52:1             deep  vs light   1.28:1
///     rem    #5B5483   6.91:1             rem   vs awake   1.37:1
///     awake  #BF472E   5.05:1             deep  vs awake   1.44:1
///                                         light vs rem     1.53:1
///                                         deep  vs rem     1.96:1
/// ```
///
/// Three of the four dark values are **near-isoluminant** — WCAG luminance 0.345,
/// 0.301 and 0.306 — so they differ by hue alone. At 1.02:1 two adjacent bands are
/// the same colour to the eye, and hue-only encoding is also what red-green colour
/// deficiency (~8% of men) removes. WCAG 2.1 SC 1.4.11 asks 3:1 of a graphical
/// object needed to understand content, and adjacent hypnogram bands are exactly
/// that.
///
/// **This is an accessibility flaw fix, authorised as a deliberate departure from
/// the verbatim-legacy rule** (owner, 2026-08-06). It is recorded here so that
/// nobody restores legacy's values later believing they are fixing a drift. The
/// numbers above are what would come back.
///
/// ## 3:1 on every pair is impossible, and here is the arithmetic
///
/// WCAG contrast is `(Yhi + 0.05) / (Ylo + 0.05)`, so contrast **multiplies** along
/// a ladder: four colours each 3:1 clear of the next need 27:1 end to end. The
/// absolute maximum sRGB offers is 21:1 (black on white), so **no four colours
/// anywhere satisfy it** — before any card or hue constraint is applied.
///
/// Requiring each stage to also clear 3:1 against its own card narrows it further:
///
/// ```text
///   dark   every stage >= 3:1 on #141419  =>  Y in [0.1216, 1.0]   span 6.12:1
///   light  every stage >= 3:1 on #FFFFFF
///          and on the page #F4F4F6        =>  Y in [0.0, 0.2686]   span 6.37:1
/// ```
///
/// A span of 6.12:1 shared over three steps is **1.829:1 per step at best**, and
/// that best spends both endpoints on pure white and a colour at the exact card
/// floor — no chroma left, so no hue identity left. So the honest target is not
/// 3:1; it is *the largest step this palette can reach while every hue survives*.
/// [kStagePairFloor] is that measured number, and it is a floor rather than a pin.
///
/// ## What was derived, and how
///
/// Worked in OKLCH. For each stage: **legacy's hue angle and legacy's chroma are
/// kept, and only OKLCH lightness moves** until WCAG luminance lands on its rung.
/// Chroma is reduced in exactly one place, and only because sRGB cannot hold it at
/// that lightness (light-theme awake, 0.1595 → 0.1185). Every hue angle lands
/// within **0.8°** of legacy's. The four are still amber, blue, purple, red-orange.
///
/// The rungs are geometric in `Y + 0.05`, which is what makes every adjacent pair
/// the same ratio — an arithmetic ladder would have crowded one end.
///
/// ## The ordering, and why it is this one
///
/// **Lightness tracks sleep depth: deep is the lightest rung, awake the darkest**,
/// in both themes. Reading a hypnogram top to bottom — awake · REM · light · deep —
/// the ramp therefore darkens upward, monotonically, in lane order.
///
/// Three reasons, in order of weight:
///
///   1. **Depth is an ordinal scale, so it earns a sequential ramp.** Four hues at
///      one lightness throw that away; that is what shipped, and it is why the set
///      read as "dull".
///   2. **Lane position and lightness then say the same thing.** The hypnogram
///      already encodes depth on its y-axis. Two carriers agreeing is redundant
///      encoding — the thing colour-blind and greyscale readers need — instead of
///      two carriers each doing half.
///   3. **It is the direction legacy's own hues already lean, so it distorts them
///      least.** Amber is the naturally lightest of these four hue families and
///      red-orange among the darkest; legacy's dark set already runs gold 0.433 >
///      blue 0.345 > awake 0.306 ≈ rem 0.301. The ramp decompresses an order that
///      was nearly there and swaps the one pair (rem/awake) that was out of it.
///      Ordering the other way would have forced light-theme deep to a near-black
///      brown at Y 0.012, which leaves the gold family in everything but hue angle.
///
/// `kSleepStages` — deep · light · rem · awake — is already the ramp order, so a
/// stacked proportion bar reads as one monotonic gradient rather than four
/// unrelated blocks.
///
/// ## What did NOT move
///
/// **Every metric hue.** `cSteps` is still `#D9A84E`, `cSpo2` `#7DA3C4`, `cSleep`
/// `#968EC9`, `cHeart` `#E07A5F` — and `cHeart` is still `alert`, the illness flag.
/// Deep sleep and the steps metric used to be one value and are now two, which is
/// the whole reason this file exists: a stage colour and a metric colour are
/// answers to different questions and only one of them was failing.
library;

import 'package:flutter/material.dart';

/// The measured floor every adjacent stage pair clears, in both themes.
///
/// **1.5:1, and it is a floor, not a pin.** The palette measures 1.55:1 (light)
/// and 1.57:1 (dark) at its worst pair; the ceiling proved in the library
/// docstring is 1.83:1. Pinning the exact value would fail the day contrast
/// *improves*, which this repo has already paid for once on `onAccent`.
///
/// It is deliberately not 3:1. See the library docstring: four colours cannot
/// reach 3:1 pairwise in any colour space, on any background.
const double kStagePairFloor = 1.5;

/// The floor every stage clears against the card it is drawn on, in both themes.
///
/// WCAG 2.1 SC 1.4.11. This one **is** reachable, and every stage clears it with
/// room: the tightest is dark `awake` at 3.15:1.
const double kStageSurfaceFloor = 3.0;

/// **The four stage colours, light theme.** Derived; see the library docstring.
///
/// Drawn on `LightPalette.surface` (`#FFFFFF`). Measured against it, and against
/// the page `#F4F4F6`, because the 3:1 floor holds on both:
///
/// ```text
///   stage   value      was        Y       card   page    OKLCH
///   deep    #B4802E    #B27F2C    0.2534  3.46   3.15    L .637  C .1153  H  74.8
///   light   #4C6E8B    #587A97    0.1455  5.37   4.89    L .524  C .0604  H 245.0
///   rem     #4F4875    #5B5483    0.0758  8.35   7.60    L .429  C .0736  H 290.1
///   awake   #631000    #BF472E    0.0302  13.09  11.91   L .325  C .1185  H  33.5
///
///   band against band          deep   light  rem
///                     light    1.55
///                     rem      2.41   1.55
///                     awake    3.78   2.44   1.57
/// ```
abstract final class LightStagePalette {
  /// **Deep sleep — the lightest rung.** Legacy's `cSteps` hue and chroma at
  /// Y 0.2534. Barely moved: the light theme's gold was already near its ceiling.
  static const Color deep = Color(0xFFB4802E);

  /// **Light sleep — second rung.** Legacy's `cSpo2` hue and chroma, one step
  /// down.
  static const Color light = Color(0xFF4C6E8B);

  /// **REM — third rung.** Legacy's `cSleep` hue and chroma, one step further.
  static const Color rem = Color(0xFF4F4875);

  /// **Awake — the darkest rung.** Legacy's `cHeart` hue exactly (33.5°), chroma
  /// clipped 0.1595 → 0.1185 because sRGB holds no more at this lightness. It is
  /// the one value in the set whose chroma moved, and the gamut moved it.
  static const Color awake = Color(0xFF631000);

  /// **A span the strap staged with a code we do not recognise.** Chroma-free,
  /// and not a fifth rung.
  ///
  /// Was `#8C8C8C`, which under the new ramp sat 1.05:1 from `deep` — visually
  /// the same colour. It is placed at the geometric midpoint of the ramp gap
  /// **nearest the card**, so an unreadable span is the quietest mark on the
  /// chart while still clearing the card at 4.29:1.
  ///
  /// **Luminance cannot do this job and is not asked to.** Every gap in a
  /// four-rung ladder is 1.56:1 wide, so the best any fifth value can manage is
  /// 1.25:1 from its neighbours, which is what this reaches. The carriers that do
  /// the work are **chroma** — this is the only value in the set with none, and
  /// every stage is asserted chromatic — and the **word**: `legendStages` adds an
  /// "Unrecognised" key exactly when a grey band was drawn.
  static const Color unstaged = Color(0xFF7A7A7A);
}

/// **The four stage colours, dark theme.** Derived; see the library docstring.
///
/// Drawn on `DarkPalette.surface` (`#141419`):
///
/// ```text
///   stage   value      was        Y       card   page    OKLCH
///   deep    #FFCC73    #D9A84E    0.6568  12.36  13.30   L .872  C .1217  H  80.0
///   light   #87AECF    #7DA3C4    0.3993  7.86   8.46    L .734  C .0640  H 244.3
///   rem     #867EB8    #968EC9    0.2345  4.97   5.35    L .623  C .0867  H 290.0
///   awake   #A8472E    #E07A5F    0.1303  3.15   3.39    L .521  C .1339  H  35.5
///
///   band against band          deep   light  rem
///                     light    1.57
///                     rem      2.48   1.58
///                     awake    3.92   2.49   1.58
/// ```
///
/// Every chroma is legacy's to four decimal places. The gold could have been
/// pushed to Y 0.88 for a 1.75:1 step, but only by dropping its chroma 0.122 →
/// 0.037, i.e. by turning the one band the owner *could* see into a white tint.
/// 0.66 is where the gold still holds legacy's full chroma.
abstract final class DarkStagePalette {
  /// **Deep sleep — the lightest rung.** Legacy's `cSteps` hue and chroma at
  /// Y 0.6568, the highest luminance that hue reaches without losing chroma.
  static const Color deep = Color(0xFFFFCC73);

  /// **Light sleep — second rung.** Legacy's `cSpo2` hue and chroma. It moves
  /// least of the four (Y 0.345 → 0.399): it was already near its rung.
  static const Color light = Color(0xFF87AECF);

  /// **REM — third rung.** Legacy's `cSleep` hue and chroma, darkened. This and
  /// `awake` were the 1.02:1 pair — the two that were literally indistinguishable.
  static const Color rem = Color(0xFF867EB8);

  /// **Awake — the darkest rung**, at 3.15:1 on the card. Legacy's `cHeart` hue
  /// and chroma, darkened; it keeps all of its chroma, unlike its light-theme
  /// counterpart.
  static const Color awake = Color(0xFFA8472E);

  /// A span staged with a code we do not recognise. See
  /// [LightStagePalette.unstaged] for the whole argument — same placement rule,
  /// same reasoning. Was `#767676`; 3.98:1 on the card.
  static const Color unstaged = Color(0xFF757575);
}
