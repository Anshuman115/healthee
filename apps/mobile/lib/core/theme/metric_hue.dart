/// Which of legacy's ten hues a metric wears — transcribed from legacy's own
/// call sites, not designed here.
///
/// Legacy has no such function: every screen names its hue inline
/// (`label: 'Steps', color: c.cSteps`). That works when one file draws every
/// card and it does not survive being split across `features/`, so the table is
/// lifted into one place. **Every entry below cites the legacy line it came
/// from**, so this stays a transcription that can be checked rather than a
/// design that has to be trusted.
///
/// ## Legacy disagrees with itself twice, and the resolution is recorded
///
///   * **Cardio load.** `today_screen.dart:1348` draws it `cHeart` (red-orange);
///     `activity_screen.dart:354` draws the same metric `cReady` (green). Two
///     different hues for one metric. Today's wins here, because Today is the
///     screen the owner opens.
///   * **Blood oxygen.** `today_screen.dart:317` draws the overnight SpO₂ card
///     `cResp` (teal); `sleep_screen.dart:350` draws the SpO₂ vitals row
///     `cSpo2` (blue). Today's wins, same reason.
///
/// Both are reported as findings rather than repaired: they are legacy's, and
/// the brief is explicit that a faithful port of something imperfect beats an
/// unrequested fix.
///
/// A third apparent conflict is not one: VO₂max is `cReady` on Today
/// (`today_screen.dart:1239`) and `green` on Activity
/// (`activity_screen.dart:172`), and those two are the **same value** in both
/// themes.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';

/// The hue for a canonical metric id.
///
/// Ids are the server's (`rhr_daily`, `steps_total`) and the strap's
/// (`resting_hr`, `spo2`), because both halves of Today draw modules and a second
/// table keyed by a second vocabulary is how one metric ends up two colours.
///
/// **The hue is a function of the metric's identity and nothing else.** There is
/// deliberately no overload taking a reading, a z-score or a direction — legacy
/// reuses two of these hues as verdicts (see `instrument_hues.dart`), and a
/// caller able to pass a value would turn every card into a verdict by accident.
///
/// An unlisted id gets [InstrumentHues.hrv], which is legacy's own fallback
/// (`today_screen.dart:905`, `_ => c.green`).
Color hueFor(InstrumentHues hues, String metric) => switch (metric) {
  // today_screen.dart:174 · 624 · 1107 · 1424
  'sleep' ||
  'sleep_debt' ||
  'sleep_debt_min' ||
  'sleep_duration' ||
  'tst_min' ||
  'sri' => hues.sleep,
  // today_screen.dart:181 · 284 · 1348
  'rhr_daily' ||
  'resting_hr' ||
  'hr' ||
  'heart_rate' ||
  'max_hr' ||
  'cardio_load' ||
  'cardio_load_trimp' => hues.heart,
  // today_screen.dart:187 · 249 · 1050 · 1295 (HRV, sleep health, MVPA)
  'hrv' ||
  'hrv_sleep_avg' ||
  'sleep_health' ||
  'sleep_health_score_4dim' ||
  'mvpa_min' ||
  'moderate_min' ||
  'vigorous_min' => hues.hrv,
  // today_screen.dart:193 · activity_screen.dart:315
  'steps_total' ||
  'steps' ||
  'steps_per_minute' ||
  'distance_m' ||
  'distance_m_daily' => hues.steps,
  // today_screen.dart:199 (energy) · 272 (stress — legacy really does use cCal)
  'active_calories' ||
  'total_calories' ||
  'basal_calories' ||
  'stress' ||
  'stress_daily' => hues.calories,
  // today_screen.dart:209 (respiratory) · 317 (blood oxygen — see the docstring)
  'respiratory_rate' ||
  'respiratory_rate_sleep' ||
  'spo2' ||
  'spo2_overnight' ||
  'spo2_overnight_min' => hues.respiratory,
  // sleep_screen.dart:352
  'temperature_c' || 'skin_temp_c' => hues.stress,
  // today_screen.dart:1162 · 1239 · activity_screen.dart:471
  'vo2max_estimate' ||
  'vo2max_submax' ||
  'biological_age' => hues.readiness,
  _ => hues.hrv,
};
