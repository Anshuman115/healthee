/// The small pure helpers legacy's Today screen keeps at file scope.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart` — `_comma`
/// (429), `_sleepNightLabel` (506), `_noSleepLastNight` (521), `_stageFoot`
/// (421), `_hypnoFromTotals` (406), `_GreetingHeader._prettyDate` (491) and the
/// `medFoot` / `highGood` / `good` closures inside `_Content.build` (159–170).
///
/// They live in one file because they are the screen's *vocabulary* — every one
/// of them turns a number into the exact words legacy prints, and a second copy
/// of any of them is a second wording. Nothing here draws.
///
/// ## The one deliberate signature change
///
/// [sleepNightLabel] and [noSleepLastNight] take `now` rather than calling
/// `DateTime.now()` as legacy does. Both decide a *sentence about staleness*, and
/// a test that cannot fix the clock cannot assert the sentence. Every caller on
/// this screen already has an injected instant (`ScreenData.now`).
library;

import 'package:healthee/data/models/last_sleep.dart';

/// `9264` → `9,264`. Legacy's `_comma`, regex and all.
String commaGrouped(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

/// `2026-08-04` → `TUE · AUG 4`. Legacy's `_prettyDate`.
///
/// Falls back to the raw string uppercased when the date will not parse, which
/// is legacy's own `catch` — an unparseable date is still information, and a
/// blank where a date belongs reads as a broken header.
String prettyDate(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso.toUpperCase();
  }
  const days = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${days[parsed.weekday - 1]} · ${months[parsed.month - 1]} ${parsed.day}';
}

/// Honest name for the sleep session on screen. Legacy's `_sleepNightLabel`.
///
/// "Last night" is a claim, and it is false when the owner was travelling and
/// did not sleep. The label counts **calendar days between waking and today**,
/// not hours, so a nap that ended at 02:00 this morning is still last night.
String sleepNightLabel(String? endIso, DateTime now) {
  if (endIso == null) {
    return 'Last night';
  }
  final end = DateTime.tryParse(endIso)?.toLocal();
  if (end == null) {
    return 'Last night';
  }
  final wake = DateTime(end.year, end.month, end.day);
  final today = DateTime(now.year, now.month, now.day);
  final daysAgo = today.difference(wake).inDays;
  if (daysAgo <= 0) {
    return 'Last night';
  }
  if (daysAgo == 1) {
    return 'Night before last';
  }
  return '$daysAgo nights ago';
}

/// True when the most recent sleep ended 24 h ago or more.
///
/// Legacy's `_noSleepLastNight`: when it is true, every overnight reading below
/// — sleep, HRV, SpO₂, breathing and their charts — is from an older night, and
/// the section gets a banner saying so.
bool noSleepLastNight(String? endIso, DateTime now) {
  final end = DateTime.tryParse(endIso ?? '')?.toLocal();
  if (end == null) {
    return false;
  }
  return now.difference(end).inHours >= 24;
}

/// `DEEP 24% · REM 24%` under the Sleep tile. Legacy's `_stageFoot`.
///
/// The denominator is light + deep + REM and deliberately **excludes awake** —
/// the percentages are of time asleep, not of time in bed. With no totals at all
/// legacy prints the em-dash form rather than `DEEP 0% · REM 0%`, because a zero
/// is a measurement and this is the absence of one.
String stageFoot(Map<String, int> totals) {
  double minutes(String key) => (totals[key] ?? 0).toDouble();
  final asleep = minutes('light') + minutes('deep') + minutes('rem');
  if (asleep == 0) {
    return 'DEEP — · REM —';
  }
  return 'DEEP ${(minutes('deep') / asleep * 100).round()}% · '
      'REM ${(minutes('rem') / asleep * 100).round()}%';
}

/// The hypnogram legacy draws in the Sleep tile. Legacy's `_hypnoFromTotals`.
///
/// Spans of zero minutes are dropped, and an unstaged night returns an **empty
/// list**, which `HHypnogram` draws as nothing.
///
/// **This is a repaired flaw, not a port.** Legacy falls back to
/// `[(stage: 'core', min: 1)]` — one full-width band in light-sleep blue for a
/// night nothing was staged. That is a chart of a measurement that was not made,
/// and it is indistinguishable from a night the strap really did score as one
/// unbroken light-sleep block. The slot keeps its 30 px either way, so the tile
/// does not move; what changes is that an unmeasured night now looks unmeasured.
List<SleepStageSpan> hypnogramSpans(List<SleepStageSpan> stages) => [
  for (final span in stages)
    if (span.durationMin > 0) span,
];

/// `6a` · `12p` · `11p` — legacy's short clock, from a real hour.
///
/// Legacy hard-codes the five captions under its 24-hour heart rate and lays
/// them out `spaceBetween`, so on every partial day they describe hours the
/// curve above them does not cover. This turns an actual hour into legacy's own
/// format so the captions can be built from the series instead.
String shortClock(int hour) {
  final wrapped = hour % 24;
  final suffix = wrapped < 12 ? 'a' : 'p';
  final twelve = wrapped % 12 == 0 ? 12 : wrapped % 12;
  return '$twelve$suffix';
}

/// `MED 55`, or `14-DAY TREND` when there is no median yet. Legacy's `medFoot`.
///
/// Four-figure medians are comma-grouped and smaller ones are not, which is
/// legacy's `m >= 1000` branch verbatim.
String medianFoot(double? median30d) {
  if (median30d == null) {
    return '14-DAY TREND';
  }
  final rounded = median30d.round();
  return 'MED ${median30d >= 1000 ? commaGrouped(rounded) : rounded}';
}

/// The metrics where a HIGHER reading is the favourable one. Legacy's `highGood`.
///
/// It decides the colour of a delta badge and nothing else. Kept as legacy's own
/// set rather than derived from `shared/format/metric_polarity.dart`: that table
/// is this rebuild's and is keyed differently, and two tables that must agree
/// about "is up good" are exactly the second definition CLAUDE.md forbids. The
/// divergence is reported rather than merged here.
const Set<String> highIsFavorable = <String>{
  'hrv_sleep_avg',
  'steps_total',
  'total_calories',
  'active_calories',
  'sleep_health_score_4dim',
  'sleep_regularity_index',
  'mvpa_min',
  'vo2max_estimate',
  'spo2_overnight',
};

/// Whether a z-score is the good direction for [metric]. Legacy's `good`.
///
/// Null for a missing z **and for exactly zero**, which is legacy's own
/// `z == 0 ? null` — a reading sitting on its own median has no direction, and
/// painting it green would be a verdict invented out of no movement.
bool? favorableDirection(String metric, double? z) {
  if (z == null || z == 0) {
    return null;
  }
  return highIsFavorable.contains(metric) ? z > 0 : z < 0;
}

/// `6:20` from minutes — the Sleep tile's figure. Legacy's inline expression at
/// `today_screen.dart:175`.
String clockDuration(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

/// `6h 20m` from minutes. Legacy's `_ReadinessBlock` and `_SleepHealthModule`.
String hoursMinutes(num minutes) =>
    '${minutes ~/ 60}h ${(minutes % 60).round()}m';

/// `6.3h` from minutes. Legacy's `_SleepDebtModule.h`.
String decimalHours(num minutes) => '${(minutes / 60).toStringAsFixed(1)}h';
