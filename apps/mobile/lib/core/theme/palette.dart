/// The ONLY file in this app allowed to contain a colour literal.
///
/// Engineering Standards §3: "Design tokens only — colors/typography/spacing from
/// the theme system, no inline `Color(0xFF…)` in feature code." A rule like that
/// needs somewhere for the hex to live, and this is it.
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

  /// The one accent — **legacy's forest green**, `HColors.light.green`.
  static const Color accent = Color(0xFF1F6F54);

  /// The accent under pressure — legacy's `greenDeep`.
  static const Color accent2 = Color(0xFF154D3A);

  /// A wash of the accent — legacy's `greenSoft`. Opaque in legacy, kept opaque.
  static const Color accentSoft = Color(0xFFE2EBE3);

  /// Text and icons sitting ON [accent] — legacy's `onGreen`.
  ///
  /// **One value in both themes, which is legacy's own choice and is ported
  /// unchanged.** It measures 5.68:1 on this theme's green and **2.14:1** on the
  /// dark theme's — below WCAG AA and below the 3:1 large-text floor. Flagged for
  /// the owner rather than corrected in the diff, because the brief is explicit
  /// that a faithful port of something imperfect beats an unrequested fix.
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

  /// The one accent — **legacy's dark green**, `HColors.dark.green`.
  static const Color accent = Color(0xFF4BBF93);

  /// The accent under pressure — legacy's `greenDeep`.
  static const Color accent2 = Color(0xFF2F8F6C);

  /// A wash of the accent — legacy's `greenSoft`.
  static const Color accentSoft = Color(0xFF1E3329);

  /// Text on [accent] — legacy's `onGreen`, the SAME value as the light theme's.
  ///
  /// 2.14:1 here. See [LightPalette.onAccent] for why it ships anyway.
  static const Color onAccent = LightPalette.onAccent;

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

  /// The number-shaped absence.
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

  /// `cSteps` — steps and distance. Also **deep sleep** on every sleep chart.
  static const Color steps = Color(0xFFB27F2C);

  /// `cCal` — calories, and legacy's stress card.
  static const Color calories = Color(0xFFCE6131);

  /// `cResp` — respiratory rate, and legacy's overnight blood-oxygen card.
  static const Color respiratory = Color(0xFF3C7A84);

  /// `cSpo2` — **light/core sleep** on every sleep chart, and zone 1. Legacy's
  /// SpO₂ vitals row on the sleep screen also uses it.
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

  /// `cSteps` — also deep sleep.
  static const Color steps = Color(0xFFD9A84E);

  /// `cCal`.
  static const Color calories = Color(0xFFE8835A);

  /// `cResp`.
  static const Color respiratory = Color(0xFF5FA9B4);

  /// `cSpo2` — also light/core sleep.
  static const Color spo2 = Color(0xFF7DA3C4);

  /// `cStress`.
  static const Color stress = Color(0xFFC98A96);

  /// `cReady` — identical to [DarkPalette.accent].
  static const Color readiness = Color(0xFF4BBF93);

  /// `cRem` — unused by legacy's screens. See [LegacyLightHues.rem].
  static const Color rem = Color(0xFFB3A9E0);
}
