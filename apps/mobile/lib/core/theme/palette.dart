/// One of the **two** files in this app allowed to contain a colour literal. The
/// other is `sleep_stage_palette.dart`.
///
/// Engineering Standards §3: "Design tokens only — colors/typography/spacing from
/// the theme system, no inline `Color(0xFF…)` in feature code." A rule like that
/// needs somewhere for the hex to live, and this is it.
///
/// **Why there are two files and not one.** This file is a transcription: the
/// approved scaffolding, plus legacy's hues to the hex, and its one reason to
/// change is "legacy's value was read wrong". `sleep_stage_palette.dart` holds
/// four values that are *derived* rather than transcribed — an authorised
/// accessibility repair with its own arithmetic — and its reason to change is "the
/// card colour moved, so re-derive the ramp". Two reasons, two files
/// (Standards §1). `test/core/colour_literal_gate_test.dart` reads `lib/` and
/// fails on a third.
///
/// ## Which design this is — and what changed on 2026-08-05
///
/// **The legacy app is now the specification.** Owner decision: *"not a single
/// change in design, every section remains as is, every tab, everything — only
/// honesty wording as mentioned."* Three things and only three may differ from
/// `~/projects/healthee-legacy/app/lib/ui/theme.dart`:
///
///   1. the typeface (Manrope, `typography.dart`),
///   2. the light/dark **scaffolding** — page, surface, ink and hairline,
///   3. honesty wording.
///
/// So this file is now in two halves, and the split is the decision:
///
///   * [LightPalette] / [DarkPalette] keep the **scaffolding** of the rebuild's
///     approved design — near-white and near-black, neutral ink, alpha hairlines.
///     Those are the paper/ink/surface/line roles the owner kept.
///   * Every other value below is **legacy's, to the hex**: the green accent
///     family, the verdict colours, and the ten per-metric hues in
///     [LegacyLightHues] / [LegacyDarkHues].
///
/// ## What was DELETED, so nobody reinstates it
///
/// `LightTagPalette` / `DarkTagPalette` — the five-hue "identity tag" system, with
/// its OKLCH hue-separation argument and its 40° floor against the verdicts. It is
/// **superseded**, not refuted: legacy has ten per-metric hues and deliberately
/// reuses two of them as verdicts, so a palette built to guarantee tags and
/// verdicts can never be confused is a palette that cannot express legacy.
///
/// ## The collision legacy makes on purpose (do not "fix" it)
///
/// Legacy's green is **HRV, readiness AND "improving"**; its red-orange is
/// **heart, cardio load AND "degrading"**. `insights_screen.dart:171` is literally
/// `improving ? c.green : c.cHeart`. Identity and judgement therefore share hues
/// here **by decision**. That is legacy's language and it is what ships.
library;

import 'package:flutter/material.dart';

/// The scaffolding, light — page, surface, ink, hairline. Kept from the rebuild.
///
/// The accent and verdict values below are legacy's; see [LegacyLightHues].
abstract final class LightPalette {
  /// Page background, behind every surface. Legacy's `paper`, this theme's value.
  static const Color bg = Color(0xFFF4F4F6);

  /// Cards and sheets. Legacy's `paper2`, this theme's value.
  static const Color surface = Color(0xFFFFFFFF);

  /// A recessed or secondary surface inside a card.
  ///
  /// Also the fill of a loading skeleton. Legacy had a fourth paper tone
  /// (`sunken`) for that; the kept scaffolding is a three-tone set, so the
  /// skeletons use this role rather than a colour nobody approved.
  static const Color surface2 = Color(0xFFFAFAFB);

  /// App frame — top bar and tab bar.
  static const Color chrome = Color(0xFFFFFFFF);

  /// Primary text and hero figures.
  static const Color ink = Color(0xFF121217);

  /// Secondary text — the sentence under a number.
  static const Color ink2 = Color(0xFF56565F);

  /// Tertiary text — labels, units, captions.
  static const Color ink3 = Color(0xFF6D6D7C);

  /// Card borders and the stronger rule. **Legacy's `line2`** by role.
  static const Color line = Color.fromRGBO(18, 18, 23, 0.10);

  /// The quieter hairline — rows inside a list. **Legacy's `line`** by role.
  ///
  /// The names are inverted between the two systems and it matters: legacy's
  /// `line2` is the STRONGER of its pair and is what `HModule` draws its border
  /// with. A port that matched on name would draw every card edge at 6%.
  static const Color line2 = Color.fromRGBO(18, 18, 23, 0.06);

  /// A rule drawn INSIDE a plot — gridlines and axis rules. See [DarkPalette.grid]
  /// for the defect this token was added to fix; the value is half of [line].
  static const Color grid = Color.fromRGBO(18, 18, 23, 0.05);

  /// The horizontal line a series is READ AGAINST — a baseline or a convention.
  ///
  /// [ink3] at 55%. It used to be opaque `ink3`, which drew the context line at
  /// the same weight as the caption naming it; owner report 2026-08-06 — *"can
  /// we make the baseline line a bit subtle in the charts"*. Louder than [grid],
  /// because a reference is a claim about a number rather than structure, and
  /// quieter than the trace and than any text.
  static const Color reference = Color.fromRGBO(109, 109, 124, 0.55);

  /// The one accent — **legacy's forest green**, `HColors.light.green`.
  static const Color accent = Color(0xFF1F6F54);

  /// The accent under pressure — legacy's `greenDeep`.
  static const Color accent2 = Color(0xFF154D3A);

  /// A wash of the accent — legacy's `greenSoft`. Opaque in legacy, kept opaque.
  static const Color accentSoft = Color(0xFFE2EBE3);

  /// Text and icons sitting ON [accent] — legacy's `onGreen`.
  ///
  /// **5.68:1 on this theme's green, so this half of legacy's value stands.** The
  /// dark theme's half did not; see [DarkPalette.onAccent].
  static const Color onAccent = Color(0xFFFBF7EF);

  /// **Judgement — favourable.** Legacy's green, the same value as [accent] and
  /// as [LegacyLightHues.hrv]. See the library docstring: legacy shares them.
  static const Color fav = accent;

  /// [fav] as a fill — legacy's `greenSoft`.
  static const Color favSoft = accentSoft;

  /// **Judgement — the middle band.** Legacy's warn amber.
  ///
  /// Legacy never put this in `HColors`; it is an inline `const Color(0xFFE0A33E)`
  /// at `today_screen.dart:19`, `profile_screen.dart:307` and
  /// `sleep_screen.dart:804` — the same literal, one value, used in both themes.
  /// Ported as legacy has it: one value, both themes.
  static const Color unf = Color(0xFFE0A33E);

  /// [unf] as a fill, at the 0.16 alpha legacy uses for a tinted verdict chip
  /// (`challenge_celebration.dart:77`, `insights_screen.dart:572`).
  static const Color unfSoft = Color.fromRGBO(224, 163, 62, 0.16);

  /// **Judgement — unfavourable, and the illness flag.** Legacy's `cHeart`.
  ///
  /// The same value as [LegacyLightHues.heart]. Legacy has no separate red.
  static const Color alert = Color(0xFFBF472E);

  /// [alert] as a fill, at legacy's 0.16.
  static const Color alertSoft = Color.fromRGBO(191, 71, 46, 0.16);

  /// The number-shaped absence — a very low-alpha fill, not a text colour.
  ///
  /// Scaffolding, and part of the honesty layer: a refusal spends no hue.
  ///
  /// `unstaged`, its sibling in that layer, moved to
  /// `LightStagePalette.unstaged`: it is only ever drawn beside the four stage
  /// colours, and it has to be re-measured whenever they move.
  static const Color hole = Color.fromRGBO(18, 18, 23, 0.045);
}

/// The scaffolding, dark. Authored, never derived by inverting light.
abstract final class DarkPalette {
  /// Page background, behind every surface.
  static const Color bg = Color(0xFF0A0A0E);

  /// Cards and sheets.
  static const Color surface = Color(0xFF141419);

  /// A recessed or secondary surface inside a card, and a skeleton's fill.
  static const Color surface2 = Color(0xFF1A1A21);

  /// App frame — top bar and tab bar.
  static const Color chrome = Color(0xFF141419);

  /// Primary text and hero figures.
  static const Color ink = Color(0xFFF3F3F6);

  /// Secondary text — the sentence under a number.
  static const Color ink2 = Color(0xFFA2A2B0);

  /// Tertiary text — labels, units, captions.
  static const Color ink3 = Color(0xFF8D8D99);

  /// Card borders and the stronger rule. Legacy's `line2` by role.
  static const Color line = Color.fromRGBO(255, 255, 255, 0.10);

  /// The quieter hairline. Legacy's `line` by role — see [LightPalette.line2].
  static const Color line2 = Color.fromRGBO(255, 255, 255, 0.055);

  /// A rule drawn INSIDE a plot — gridlines and axis rules.
  ///
  /// **The defect it replaced, 2026-08-06.** Owner report: *"gridlines are
  /// almost white"*. Three painters drew their grid as
  /// `colors.line.withValues(alpha: 0.5)` — 0.7 in `h_stacked_sleep` — and
  /// `withValues` **replaces** the alpha instead of scaling it. That is the
  /// exact mistake `chart_primitives.dart`'s `revealed()` was written to
  /// prevent, one file over. [line] is a 10% hairline, so those gridlines were
  /// white at **50% and 70%** — five and seven times their intended weight —
  /// and the light theme drew the same lines near-black. This value is what the
  /// arithmetic meant: half of [line].
  static const Color grid = Color.fromRGBO(255, 255, 255, 0.05);

  /// The horizontal line a series is read against. [ink3] at 55%; see
  /// [LightPalette.reference].
  static const Color reference = Color.fromRGBO(141, 141, 153, 0.55);

  /// The one accent — **legacy's dark green**, `HColors.dark.green`.
  static const Color accent = Color(0xFF4BBF93);

  /// The accent under pressure — legacy's `greenDeep`.
  static const Color accent2 = Color(0xFF2F8F6C);

  /// A wash of the accent — legacy's `greenSoft`.
  static const Color accentSoft = Color(0xFF1E3329);

  /// Text and icons sitting ON [accent]. **The one legacy value not ported.**
  ///
  /// Legacy uses its off-white `onGreen` on both greens. On this theme's green it
  /// measures **2.14:1** — under WCAG AA (4.5:1) and under even the 3:1
  /// large-text floor — so the word inside a filled accent button is a light
  /// smudge on a light-mid green. That is legibility, not design: the accent
  /// itself is untouched and still legacy's `#4BBF93`, and only the ink on top of
  /// it moves.
  ///
  /// **No new colour was introduced.** This is [bg], the page the whole dark
  /// theme is already drawn on, which measures **8.63:1** on the accent and
  /// **6.70:1** on [alert] (`onAccent` doubles as Material's `onError`, where the
  /// off-white was 2.76:1 — the same failure, one token over).
  ///
  /// Legacy's own value is kept in the light theme, where it passes. The pair is
  /// asymmetric because legacy's two greens are: `#1F6F54` is dark enough for
  /// off-white and `#4BBF93` is not.
  static const Color onAccent = bg;

  /// **Judgement — favourable.** Legacy's green, shared with [accent].
  static const Color fav = accent;

  /// [fav] as a fill — legacy's `greenSoft`.
  static const Color favSoft = accentSoft;

  /// **Judgement — the middle band.** Legacy's warn amber, one value in both
  /// themes because legacy wrote one literal. See [LightPalette.unf].
  static const Color unf = LightPalette.unf;

  /// [unf] as a fill, at legacy's 0.16.
  static const Color unfSoft = LightPalette.unfSoft;

  /// **Judgement — unfavourable, and the illness flag.** Legacy's `cHeart`.
  static const Color alert = Color(0xFFE07A5F);

  /// [alert] as a fill, at legacy's 0.16.
  static const Color alertSoft = Color.fromRGBO(224, 122, 95, 0.16);

  /// The number-shaped absence. See [LightPalette.hole] for where `unstaged`
  /// went.
  static const Color hole = Color.fromRGBO(255, 255, 255, 0.05);
}

/// **Legacy's ten per-metric hues, light — transcribed from
/// `healthee-legacy/app/lib/ui/theme.dart`, `HColors.light`.**
///
/// Every value here is legacy's to the hex. The field names drop legacy's `c`
/// prefix (`cSleep` → [sleep]) because the prefix meant "this is a metric colour"
/// in a class that also held paper and ink, and this class holds nothing else.
///
/// **Two of these ARE verdict colours.** [hrv] and [readiness] are the same value
/// as [LightPalette.accent] and [LightPalette.fav]; [heart] is
/// [LightPalette.alert]. Legacy shares them deliberately — see the library
/// docstring. The duplication is written out rather than aliased so that a reader
/// diffing this file against legacy's `HColors.light` sees the same ten lines in
/// the same order.
abstract final class LegacyLightHues {
  /// `cSleep` — sleep, sleep debt, the sleep gauge. Muted indigo.
  static const Color sleep = Color(0xFF5B5483);

  /// `cHeart` — heart rate, resting HR, cardio load. Also the "degrading"
  /// verdict and the illness flag ([LightPalette.alert]).
  static const Color heart = Color(0xFFBF472E);

  /// `cHrv` — HRV. **Identical to the green accent**, in legacy and here.
  static const Color hrv = Color(0xFF1F6F54);

  /// `cSteps` — steps and distance.
  ///
  /// It **used to be deep sleep as well**, in legacy and in this port. The stage
  /// half moved to `LightStagePalette.deep`; this value did not move a bit, so
  /// the steps tile is unchanged. See `sleep_stage_palette.dart` for why they
  /// had to split.
  static const Color steps = Color(0xFFB27F2C);

  /// `cCal` — calories, and legacy's stress card.
  static const Color calories = Color(0xFFCE6131);

  /// `cResp` — respiratory rate, and legacy's overnight blood-oxygen card.
  static const Color respiratory = Color(0xFF3C7A84);

  /// `cSpo2` — zone 1, and legacy's SpO₂ vitals row on the sleep screen. It was
  /// **light/core sleep** too; that half is now `LightStagePalette.light`.
  static const Color spo2 = Color(0xFF587A97);

  /// `cStress` — skin temperature on legacy's sleep screen. Despite the name,
  /// legacy's stress card wears [calories].
  static const Color stress = Color(0xFFA55F6D);

  /// `cReady` — VO₂max, biological age, regularity, training load. **Identical
  /// to the green accent**, in legacy and here.
  static const Color readiness = Color(0xFF1F6F54);

  /// `cRem` — defined by legacy and **used by no legacy screen**; REM sleep is
  /// drawn in [sleep]. Ported because the hue set is ported whole.
  static const Color rem = Color(0xFF8A7FB8);
}

/// **Legacy's ten per-metric hues, dark — `HColors.dark`.** See
/// [LegacyLightHues] for what each one is for; the roles are identical.
abstract final class LegacyDarkHues {
  /// `cSleep`.
  static const Color sleep = Color(0xFF968EC9);

  /// `cHeart` — also [DarkPalette.alert].
  static const Color heart = Color(0xFFE07A5F);

  /// `cHrv` — identical to [DarkPalette.accent].
  static const Color hrv = Color(0xFF4BBF93);

  /// `cSteps`. It was deep sleep too; see [LegacyLightHues.steps].
  static const Color steps = Color(0xFFD9A84E);

  /// `cCal`.
  static const Color calories = Color(0xFFE8835A);

  /// `cResp`.
  static const Color respiratory = Color(0xFF5FA9B4);

  /// `cSpo2`. It was light/core sleep too; see [LegacyLightHues.spo2].
  static const Color spo2 = Color(0xFF7DA3C4);

  /// `cStress`.
  static const Color stress = Color(0xFFC98A96);

  /// `cReady` — identical to [DarkPalette.accent].
  static const Color readiness = Color(0xFF4BBF93);

  /// `cRem` — unused by legacy's screens. See [LegacyLightHues.rem].
  static const Color rem = Color(0xFFB3A9E0);
}

/// Legacy's seven owner-selectable accents, authored independently for light/dark.
abstract final class AppearancePalette {
  static const accents = <List<Color>>[
    [Color(0xFF1F6F54), Color(0xFF4BBF93)],
    [Color(0xFFC2553A), Color(0xFFEC8568)],
    [Color(0xFFB07D1C), Color(0xFFE2B24E)],
    [Color(0xFF0E7B8A), Color(0xFF3FBECE)],
    [Color(0xFF4A55BE), Color(0xFF8B97EE)],
    [Color(0xFFA63E72), Color(0xFFDB7DAC)],
    [Color(0xFFD95448), Color(0xFFE8796C)],
  ];
  static const neutralBg = Color(0xFF121214);
  static const neutralSurface = Color(0xFF1B1B20);
  static const neutralSunken = Color(0xFF0C0C0F);
  static const neutralLine = Color(0xFF2A2A31);
  static const neutralLine2 = Color(0xFF3A3A43);
  static const blackBg = Color(0xFF000000);
  static const blackSurface = Color(0xFF0C0C0D);
  static const blackLine = Color(0xFF1B1B1E);
  static const blackLine2 = Color(0xFF2C2C30);
}
